#ifndef LINYU_GYRO_H
#define LINYU_GYRO_H

#include <asm/ptrace.h>
#include <linux/build_bug.h>
#include <linux/compiler.h>
#include <linux/errno.h>
#include <linux/kprobes.h>
#include <linux/mutex.h>
#include <linux/sched.h>
#include <linux/string.h>
#include <linux/types.h>
#include <linux/uaccess.h>

#include "io_struct.h"

#define ASENSOR_TYPE_GYROSCOPE 4
#define ASENSOR_TYPE_GYROSCOPE_UNCAL 16
#define ASENSOR_EVENT_SIZE 0x68
#define ASEVENT_OFF_TYPE 8
#define ASEVENT_OFF_DATA 24
#define GYRO_MAX_EVENTS 4096

struct ASensorEvent_kernel
{
    s32 version;
    s32 sensor;
    s32 type;
    s32 reserved0;
    s64 timestamp;
    union
    {
        u32 data[16];
    };
    u32 flags;
    s32 reserved1[3];
};

static u32 gyro_add_float_ieee754(u32 a, u32 b)
{
    u32 sign_a = a & 0x80000000u;
    u32 sign_b = b & 0x80000000u;
    int exp_a = (a >> 23) & 0xFF;
    int exp_b = (b >> 23) & 0xFF;
    u32 mant_a = (a & 0x7FFFFFu) | 0x800000u;
    u32 mant_b = (b & 0x7FFFFFu) | 0x800000u;
    int exp_r;
    int exp_diff;
    u64 mant_r;
    u32 sign_r;

    if (exp_a == 0)
        return b;
    if (exp_b == 0)
        return a;
    if (exp_a == 0xFF || exp_b == 0xFF)
        return (exp_a == 0xFF) ? a : b;

    if (exp_a < exp_b)
    {
        exp_diff = exp_b - exp_a;
        mant_a = exp_diff >= 31 ? 0 : mant_a >> exp_diff;
        exp_r = exp_b;
    }
    else
    {
        exp_diff = exp_a - exp_b;
        mant_b = exp_diff >= 31 ? 0 : mant_b >> exp_diff;
        exp_r = exp_a;
    }

    if (sign_a == sign_b)
    {
        mant_r = (u64)mant_a + mant_b;
        sign_r = sign_a;
    }
    else if (mant_a >= mant_b)
    {
        mant_r = (u64)mant_a - mant_b;
        sign_r = sign_a;
    }
    else
    {
        mant_r = (u64)mant_b - mant_a;
        sign_r = sign_b;
    }

    if (mant_r == 0)
        return 0;

    while (mant_r > 0xFFFFFFu && exp_r < 0xFE)
    {
        mant_r >>= 1;
        exp_r++;
    }
    while (mant_r < 0x800000u && mant_r != 0 && exp_r > 1)
    {
        mant_r <<= 1;
        exp_r--;
    }

    return sign_r | ((u32)exp_r << 23) | ((u32)mant_r & 0x7FFFFFu);
}

static bool gyro_enabled;
static u32 gyro_type_mask = LSDRIVER_GYRO_MASK_ALL;
static u32 gyro_x_raw;
static u32 gyro_y_raw;
static pid_t gyro_cached_system_server_tgid = -1;

static DEFINE_MUTEX(gyro_ctrl_lock);

static struct kprobe gyro_sendto_kp;
static bool gyro_sendto_kp_registered;
static bool gyro_hooked_syscall_wrapper;

static int gyro_sendto_pre(struct kprobe *p, struct pt_regs *regs)
{
    char __user *ubuf;
    size_t len;
    size_t n;
    size_t i;
    u32 mask;
    u32 x_raw;
    u32 y_raw;
    pid_t cur_tgid;

    (void)p;

    if (!READ_ONCE(gyro_enabled))
        return 0;

    cur_tgid = current->tgid;
    if (cur_tgid != READ_ONCE(gyro_cached_system_server_tgid))
    {
        if (!current->group_leader ||
            strcmp(current->group_leader->comm, "system_server") != 0)
            return 0;
        WRITE_ONCE(gyro_cached_system_server_tgid, cur_tgid);
    }

    if (gyro_hooked_syscall_wrapper)
    {
        struct pt_regs *uregs = (struct pt_regs *)regs->regs[0];
        if (unlikely(!uregs))
            return 0;
        ubuf = (char __user *)uregs->regs[1];
        len = (size_t)uregs->regs[2];
    }
    else
    {
        ubuf = (char __user *)regs->regs[1];
        len = (size_t)regs->regs[2];
    }

    if (!ubuf || len == 0 || (len % ASENSOR_EVENT_SIZE))
        return 0;

    n = len / ASENSOR_EVENT_SIZE;
    if (n > GYRO_MAX_EVENTS)
        return 0;

    mask = READ_ONCE(gyro_type_mask);
    x_raw = READ_ONCE(gyro_x_raw);
    y_raw = READ_ONCE(gyro_y_raw);

    for (i = 0; i < n; i++)
    {
        char __user *ev = ubuf + i * ASENSOR_EVENT_SIZE;
        s32 type;
        u32 xy[2];

        if (copy_from_user(&type, ev + ASEVENT_OFF_TYPE, sizeof(type)))
            continue;

        if (!((type == ASENSOR_TYPE_GYROSCOPE &&
               (mask & LSDRIVER_GYRO_MASK_GYRO)) ||
              (type == ASENSOR_TYPE_GYROSCOPE_UNCAL &&
               (mask & LSDRIVER_GYRO_MASK_UNCAL))))
            continue;

        if (copy_from_user(xy, ev + ASEVENT_OFF_DATA, sizeof(xy)))
            continue;

        xy[0] = gyro_add_float_ieee754(xy[0], x_raw);
        xy[1] = gyro_add_float_ieee754(xy[1], y_raw);

        if (copy_to_user(ev + ASEVENT_OFF_DATA, xy, sizeof(xy)))
            continue;
    }

    return 0;
}

struct gyro_kp_target
{
    const char *name;
    bool is_wrapper;
};

static const struct gyro_kp_target gyro_kp_targets[] = {
    {"__arm64_sys_sendto", true},
    {"__se_sys_sendto", false},
    {"sys_sendto", false},
    {NULL, false},
};

static inline int linyu_gyro_init(void)
{
    int ret = -ENOENT;
    int idx;
    unsigned long sym;

    BUILD_BUG_ON(sizeof(struct ASensorEvent_kernel) != ASENSOR_EVENT_SIZE);

    if (gyro_sendto_kp_registered)
        return 0;

    for (idx = 0; gyro_kp_targets[idx].name; idx++)
    {
        memset(&gyro_sendto_kp, 0, sizeof(gyro_sendto_kp));
        gyro_sendto_kp.symbol_name = gyro_kp_targets[idx].name;
        gyro_sendto_kp.pre_handler = gyro_sendto_pre;

        ret = register_kprobe(&gyro_sendto_kp);
        if (ret == 0)
        {
            gyro_hooked_syscall_wrapper = gyro_kp_targets[idx].is_wrapper;
            goto registered;
        }

        sym = generic_kallsyms_lookup_name(gyro_kp_targets[idx].name);
        if (!sym)
            continue;

        memset(&gyro_sendto_kp, 0, sizeof(gyro_sendto_kp));
        gyro_sendto_kp.addr = (kprobe_opcode_t *)sym;
        gyro_sendto_kp.pre_handler = gyro_sendto_pre;

        ret = register_kprobe(&gyro_sendto_kp);
        if (ret == 0)
        {
            gyro_hooked_syscall_wrapper = gyro_kp_targets[idx].is_wrapper;
            goto registered;
        }
    }

    pr_debug("gyro: failed to register kprobe on sendto variants: %d\n", ret);
    return ret;

registered:
    gyro_sendto_kp_registered = true;
    pr_debug("gyro: kprobe on %s registered wrapper=%d\n",
             gyro_kp_targets[idx].name, gyro_hooked_syscall_wrapper);
    return 0;
}

static inline void linyu_gyro_disable(void)
{
    mutex_lock(&gyro_ctrl_lock);
    gyro_enabled = false;
    gyro_cached_system_server_tgid = -1;
    mutex_unlock(&gyro_ctrl_lock);
}

static inline void linyu_gyro_exit(void)
{
    linyu_gyro_disable();

    if (gyro_sendto_kp_registered)
    {
        unregister_kprobe(&gyro_sendto_kp);
        gyro_sendto_kp_registered = false;
        pr_debug("gyro: kprobe unregistered\n");
    }
}

static inline int linyu_gyro_config(struct gyro_config *cmd)
{
    if (!cmd)
        return -EINVAL;

    if (cmd->enable && !gyro_sendto_kp_registered)
        return -ENODEV;

    if (cmd->type_mask == 0)
        cmd->type_mask = LSDRIVER_GYRO_MASK_ALL;

    mutex_lock(&gyro_ctrl_lock);
    gyro_x_raw = cmd->x_raw;
    gyro_y_raw = cmd->y_raw;
    gyro_type_mask = cmd->type_mask;
    gyro_enabled = cmd->enable != 0;
    if (gyro_enabled)
        gyro_cached_system_server_tgid = -1;
    mutex_unlock(&gyro_ctrl_lock);

    cmd->enable = gyro_enabled ? 1 : 0;
    cmd->type_mask = gyro_type_mask;
    cmd->x_raw = gyro_x_raw;
    cmd->y_raw = gyro_y_raw;
    return 0;
}

#endif // LINYU_GYRO_H
