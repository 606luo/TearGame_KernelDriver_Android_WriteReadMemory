/**
 * ============================================================================
 * 泪心开源驱动 - TearGame Open Source Driver
 * ============================================================================
 * 作者 (Author): 泪心 (Tear)
 * QQ: 2254013571
 * 邮箱 (Email): tearhacker@outlook.com
 * 电报 (Telegram): t.me/TearGame
 * GitHub: github.com/tearhacker
 * ============================================================================
 * 本项目完全免费开源，代码明文公开
 * This project is completely free and open source with clear code
 * 
 * 禁止用于引流盈利，保留开源版权所有
 * Commercial use for profit is prohibited, all open source rights reserved
 * 
 * 凡是恶意盈利者需承担法律责任
 * Those who maliciously profit will bear legal responsibility
 * ============================================================================
 */

#include <linux/module.h>
#include <linux/tty.h>
#include <linux/anon_inodes.h>
#include <linux/fcntl.h>
#include <linux/fdtable.h>
#include <linux/file.h>
#include <linux/fs.h>
#include <linux/kprobes.h>
#include <linux/mutex.h>
#include <linux/slab.h>
#include <linux/stddef.h>
#include <linux/task_work.h>
#include <linux/uaccess.h>
#include <linux/version.h>
#include <linux/vmalloc.h>
#include "comm.h"
#include "io_struct.h"
#include "hwbp.h"
#include "memory.h"
#include "process.h"
#include "virtual_input.h"
#include "linyu_gyro.h"
#include "hide_process.h"
#include "hide_kgsl.h"
//原作者JiangNight  源码存在严重问题 加载格机 重启  黑砖    加载失败  kernel pacni 各种问题
//泪心已经彻底修复优化
	//printk(KERN_INFO "[TearGame] QQ: 2254013571\n");
	//printk(KERN_INFO "[TearGame] Email: tearhacker@outlook.com\n");
//printk(KERN_INFO "[TearGame] Telegram: t.me/TearGame\n");
	//(KERN_INFO "[TearGame] GitHub: github.com/tearhacker\n");

	//原项目链接 https://github.com/Jiang-Night/Kernel_driver_hack
	//泪心驱动完整开源读写内核源码新项目链接 https://github.com/tearhacker/TearGame_KernelDriver_Android_WriteReadMemory

#if defined(__aarch64__)
#define TEARGAME_PRCTL_SYMBOL "__arm64_sys_prctl"
#define TEARGAME_PT_REAL_REGS(pt) ((struct pt_regs *)((pt)->regs[0]))
#define TEARGAME_PT_REGS_ARG1(pt) ((pt)->regs[0])
#define TEARGAME_PT_REGS_ARG2(pt) ((pt)->regs[1])
#define TEARGAME_PT_REGS_ARG3(pt) ((pt)->regs[2])
#define TEARGAME_PT_REGS_ARG5(pt) ((pt)->regs[4])
#else
#error "DraKernel only supports arm64"
#endif

#define TEARGAME_FD_NAME "[DraKernel]"

struct teargame_hwbp_request
{
	pid_t pid;
	uint64_t num_brps;
	uint64_t num_wrps;
	uint64_t info;
};

#define DRA_HWBP_INFO _IOWR('D', 12, struct teargame_hwbp_request)
#define DRA_HWBP_SET _IOW('D', 13, struct teargame_hwbp_request)
#define DRA_HWBP_GET _IOWR('D', 14, struct teargame_hwbp_request)
#define DRA_HWBP_REMOVE _IOW('D', 15, struct teargame_hwbp_request)
#define DRA_TOUCH_INIT _IOWR('D', 16, struct virtual_input)
#define DRA_TOUCH_DOWN _IOW('D', 17, struct virtual_input)
#define DRA_TOUCH_MOVE _IOW('D', 18, struct virtual_input)
#define DRA_TOUCH_UP _IOW('D', 19, struct virtual_input)
#define DRA_GYRO_CONFIG _IOWR('D', 20, struct gyro_config)
#define DRA_HIDE_SELF _IO('D', 21)
#define DRA_UNHIDE_SELF _IO('D', 22)

struct teargame_fd_ctx
{
	struct mutex lock;
	pid_t owner_tgid;
	bool hwbp_active;
	bool hidden;
	bool kgsl_hidden;
	struct hwbp_info *bp_info;
};

struct teargame_install_fd_work
{
	struct callback_head cb;
	int __user *outp;
};

static int (*fn_task_work_add)(struct task_struct *task,
							   struct callback_head *work,
							   enum task_work_notify_mode notify);

static DEFINE_MUTEX(teargame_touch_lock);
static bool teargame_module_hidden;

static void teargame_list_del_init_nocheck(struct list_head *entry)
{
	struct list_head *prev;
	struct list_head *next;

	if (!entry || entry->next == entry || entry->prev == entry)
		return;

	prev = entry->prev;
	next = entry->next;
	next->prev = prev;
	prev->next = next;
	INIT_LIST_HEAD(entry);
}

static unsigned long teargame_lookup_symbol(const char *name)
{
	typedef unsigned long (*kallsyms_lookup_name_t)(const char *name);
	static kallsyms_lookup_name_t kallsyms_lookup_name_fn;
	struct kprobe kp = {
		.symbol_name = "kallsyms_lookup_name",
	};

	if (!kallsyms_lookup_name_fn)
	{
		if (register_kprobe(&kp) != 0)
			return 0;
		kallsyms_lookup_name_fn = (kallsyms_lookup_name_t)kp.addr;
		unregister_kprobe(&kp);
	}

	return kallsyms_lookup_name_fn ? kallsyms_lookup_name_fn(name) : 0;
}

static void teargame_hide_module_visibility(void)
{
	struct module_use *use, *tmp;
	void (*fn_kobject_del)(struct kobject *kobj);
	void (*fn_sysfs_remove_link)(struct kobject *kobj, const char *name);

	if (teargame_module_hidden)
		return;

	fn_kobject_del = (void *)teargame_lookup_symbol("kobject_del");
	fn_sysfs_remove_link = (void *)teargame_lookup_symbol("sysfs_remove_link");

#if LINUX_VERSION_CODE < KERNEL_VERSION(6, 12, 0)
	{
		struct vmap_area *va, *vtmp;
		struct list_head *vmap_area_list;
		struct rb_root *vmap_area_root;
		void (*fn_rb_erase)(struct rb_node *node, struct rb_root *root);

		vmap_area_list = (struct list_head *)teargame_lookup_symbol("vmap_area_list");
		vmap_area_root = (struct rb_root *)teargame_lookup_symbol("vmap_area_root");
		fn_rb_erase = (void *)teargame_lookup_symbol("rb_erase");
		if (vmap_area_list && vmap_area_root)
		{
			list_for_each_entry_safe(va, vtmp, vmap_area_list, list)
			{
				if ((unsigned long)THIS_MODULE > va->va_start &&
					(unsigned long)THIS_MODULE < va->va_end)
				{
					teargame_list_del_init_nocheck(&va->list);
					if (fn_rb_erase)
						fn_rb_erase(&va->rb_node, vmap_area_root);
					break;
				}
			}
		}
	}
#endif

	teargame_list_del_init_nocheck(&THIS_MODULE->list);
	if (fn_kobject_del)
		fn_kobject_del(&THIS_MODULE->mkobj.kobj);

	list_for_each_entry_safe(use, tmp, &THIS_MODULE->target_list, target_list)
	{
		teargame_list_del_init_nocheck(&use->source_list);
		teargame_list_del_init_nocheck(&use->target_list);
		if (fn_sysfs_remove_link)
			fn_sysfs_remove_link(use->target->holders_dir, THIS_MODULE->name);
		kfree(use);
	}

	teargame_module_hidden = true;
}

static int teargame_copy_req_field_from_user(void *dst, void __user *argp, size_t off, size_t len)
{
	if (copy_from_user(dst, (char __user *)argp + off, len))
		return -EFAULT;
	return 0;
}

static int teargame_copy_req_field_to_user(void __user *argp, size_t off, const void *src, size_t len)
{
	if (copy_to_user((char __user *)argp + off, src, len))
		return -EFAULT;
	return 0;
}

static int teargame_finish_request(void __user *argp, int status)
{
	bool kernel_done = false;
	bool user_done = true;
	int ret;

	ret = teargame_copy_req_field_to_user(argp, offsetof(struct req_obj, status), &status, sizeof(status));
	if (ret)
		return ret;

	ret = teargame_copy_req_field_to_user(argp, offsetof(struct req_obj, kernel), &kernel_done, sizeof(kernel_done));
	if (ret)
		return ret;

	return teargame_copy_req_field_to_user(argp, offsetof(struct req_obj, user), &user_done, sizeof(user_done));
}

static void teargame_cleanup_ctx_locked(struct teargame_fd_ctx *ctx)
{
	if (!ctx)
		return;

	if (ctx->hwbp_active)
	{
		remove_process_hwbp();
		ctx->hwbp_active = false;
	}

	if (ctx->bp_info)
	{
		vfree(ctx->bp_info);
		ctx->bp_info = NULL;
	}

	if (ctx->hidden)
	{
		hide_process_remove(ctx->owner_tgid);
		ctx->hidden = false;
	}
	if (ctx->kgsl_hidden)
	{
		hide_kgsl_remove(ctx->owner_tgid);
		ctx->kgsl_hidden = false;
	}

	mutex_lock(&teargame_touch_lock);
	v_touch_destroy();
	mutex_unlock(&teargame_touch_lock);
	linyu_gyro_disable();
}

static int teargame_ioctl_request(struct teargame_fd_ctx *ctx, void __user *argp)
{
	enum sm_req_op op;
	int pid;
	int status = 0;
	int ret;

	if (!ctx || !argp)
		return -EINVAL;

	ret = teargame_copy_req_field_from_user(&op, argp, offsetof(struct req_obj, op), sizeof(op));
	if (ret)
		return ret;

	ret = teargame_copy_req_field_from_user(&pid, argp, offsetof(struct req_obj, pid), sizeof(pid));
	if (ret)
		return ret;

	mutex_lock(&ctx->lock);
	switch (op)
	{
	case op_brps_weps_info:
	{
		uint64_t num_brps = get_brps_num();
		uint64_t num_wrps = get_wrps_num();

		ret = teargame_copy_req_field_to_user(argp,
											  offsetof(struct req_obj, bp_info) + offsetof(struct hwbp_info, num_brps),
											  &num_brps, sizeof(num_brps));
		if (ret)
		{
			mutex_unlock(&ctx->lock);
			return ret;
		}

		ret = teargame_copy_req_field_to_user(argp,
											  offsetof(struct req_obj, bp_info) + offsetof(struct hwbp_info, num_wrps),
											  &num_wrps, sizeof(num_wrps));
		if (ret)
		{
			mutex_unlock(&ctx->lock);
			return ret;
		}
		break;
	}
	case op_set_process_hwbp:
		if (!ctx->bp_info)
		{
			ctx->bp_info = vzalloc(sizeof(*ctx->bp_info));
			if (!ctx->bp_info)
			{
				status = -ENOMEM;
				break;
			}
		}

		ret = teargame_copy_req_field_from_user(ctx->bp_info, argp, offsetof(struct req_obj, bp_info), sizeof(*ctx->bp_info));
		if (ret)
		{
			mutex_unlock(&ctx->lock);
			return ret;
		}

		if (ctx->hwbp_active)
		{
			remove_process_hwbp();
			ctx->hwbp_active = false;
		}

		status = set_process_hwbp(pid, ctx->bp_info);
		if (!status)
			ctx->hwbp_active = true;
		break;
	case op_get_process_hwbp:
		if (!ctx->bp_info)
		{
			status = -ENOENT;
			break;
		}

		ret = teargame_copy_req_field_to_user(argp, offsetof(struct req_obj, bp_info), ctx->bp_info, sizeof(*ctx->bp_info));
		if (ret)
		{
			mutex_unlock(&ctx->lock);
			return ret;
		}
		break;
	case op_remove_process_hwbp:
	case op_kexit:
		teargame_cleanup_ctx_locked(ctx);
		break;
	default:
		status = -EOPNOTSUPP;
		break;
	}
	mutex_unlock(&ctx->lock);

	return teargame_finish_request(argp, status);
}

static long teargame_ioctl_hwbp(struct teargame_fd_ctx *ctx, unsigned int cmd, unsigned long arg)
{
	struct teargame_hwbp_request req;
	struct hwbp_info __user *uinfo;
	int status = 0;

	if (!ctx || !arg)
		return -EINVAL;

	if (copy_from_user(&req, (void __user *)arg, sizeof(req)))
		return -EFAULT;

	uinfo = (struct hwbp_info __user *)(uintptr_t)req.info;

	mutex_lock(&ctx->lock);
	switch (cmd)
	{
	case DRA_HWBP_INFO:
		req.num_brps = get_brps_num();
		req.num_wrps = get_wrps_num();
		if (copy_to_user((void __user *)arg, &req, sizeof(req)))
		{
			mutex_unlock(&ctx->lock);
			return -EFAULT;
		}
		break;
	case DRA_HWBP_SET:
		if (req.pid <= 0 || !uinfo)
		{
			status = -EINVAL;
			break;
		}

		if (!ctx->bp_info)
		{
			ctx->bp_info = vzalloc(sizeof(*ctx->bp_info));
			if (!ctx->bp_info)
			{
				status = -ENOMEM;
				break;
			}
		}

		if (copy_from_user(ctx->bp_info, uinfo, sizeof(*ctx->bp_info)))
		{
			status = -EFAULT;
			break;
		}

		if (ctx->hwbp_active)
		{
			remove_process_hwbp();
			ctx->hwbp_active = false;
		}

		status = set_process_hwbp(req.pid, ctx->bp_info);
		if (!status)
			ctx->hwbp_active = true;
		break;
	case DRA_HWBP_GET:
		if (!uinfo)
		{
			status = -EINVAL;
			break;
		}
		if (!ctx->bp_info)
		{
			status = -ENOENT;
			break;
		}
		if (copy_to_user(uinfo, ctx->bp_info, sizeof(*ctx->bp_info)))
			status = -EFAULT;
		break;
	case DRA_HWBP_REMOVE:
		teargame_cleanup_ctx_locked(ctx);
		break;
	default:
		status = -ENOTTY;
		break;
	}
	mutex_unlock(&ctx->lock);

	return status;
}

static long teargame_ioctl_touch(unsigned int cmd, unsigned long arg)
{
	struct virtual_input vinput;
	enum sm_req_op op;
	int status = 0;

	if (!arg)
		return -EINVAL;

	if (copy_from_user(&vinput, (void __user *)arg, sizeof(vinput)))
		return -EFAULT;

	mutex_lock(&teargame_touch_lock);
	switch (cmd)
	{
	case DRA_TOUCH_INIT:
		status = v_touch_init(&vinput.POSITION_X, &vinput.POSITION_Y);
		if (!status && copy_to_user((void __user *)arg, &vinput, sizeof(vinput)))
			status = -EFAULT;
		break;
	case DRA_TOUCH_DOWN:
		op = op_down;
		v_touch_event(op, vinput.slot, vinput.x, vinput.y);
		break;
	case DRA_TOUCH_MOVE:
		op = op_move;
		v_touch_event(op, vinput.slot, vinput.x, vinput.y);
		break;
	case DRA_TOUCH_UP:
		op = op_up;
		v_touch_event(op, vinput.slot, 0, 0);
		break;
	default:
		status = -ENOTTY;
		break;
	}
	mutex_unlock(&teargame_touch_lock);

	return status;
}

static long teargame_ioctl_gyro(unsigned long arg)
{
	struct gyro_config gyro;
	int status;

	if (!arg)
		return -EINVAL;

	if (copy_from_user(&gyro, (void __user *)arg, sizeof(gyro)))
		return -EFAULT;

	status = linyu_gyro_config(&gyro);
	if (!status && copy_to_user((void __user *)arg, &gyro, sizeof(gyro)))
		status = -EFAULT;

	return status;
}

static long teargame_ioctl_hide(struct teargame_fd_ctx *ctx, unsigned int cmd)
{
	int status = 0;
	int ret;

	if (!ctx)
		return -EINVAL;

	mutex_lock(&ctx->lock);
	switch (cmd)
	{
	case DRA_HIDE_SELF:
		if (!ctx->hidden)
		{
			status = hide_process_install(ctx->owner_tgid);
			if (!status)
				ctx->hidden = true;
		}
		if (!ctx->kgsl_hidden)
		{
			ret = hide_kgsl_install(ctx->owner_tgid);
			if (!ret)
				ctx->kgsl_hidden = true;
		}
		break;
	case DRA_UNHIDE_SELF:
		if (ctx->hidden)
		{
			hide_process_remove(ctx->owner_tgid);
			ctx->hidden = false;
		}
		if (ctx->kgsl_hidden)
		{
			hide_kgsl_remove(ctx->owner_tgid);
			ctx->kgsl_hidden = false;
		}
		break;
	default:
		status = -ENOTTY;
		break;
	}
	mutex_unlock(&ctx->lock);

	return status;
}

static long teargame_dispatch_cmd(unsigned int const cmd, unsigned long const arg)
{
	switch (cmd)
	{
	case OP_INIT_KEY:
		return 0;
	case OP_READ_MEM:
	{
		COPY_MEMORY cm;
		if (copy_from_user(&cm, (void __user *)arg, sizeof(cm)) != 0)
		{
			return -1;
		}
		if (read_process_memory(cm.pid, cm.addr, cm.buffer, cm.size) == false)
		{
			return -1;
		}
		break;
	}
	case OP_WRITE_MEM:
	{
		COPY_MEMORY cm;
		if (copy_from_user(&cm, (void __user *)arg, sizeof(cm)) != 0)
		{
			return -1;
		}
		if (write_process_memory(cm.pid, cm.addr, cm.buffer, cm.size) == false)
		{
			return -1;
		}
		break;
	}
	case OP_MODULE_BASE:
	{
		request req;
		char name[0x100] = {0};
		if (copy_from_user(&req, (void __user *)arg, sizeof(req)) != 0 || copy_from_user(name, (void __user *)req.buffer, sizeof(name) - 1) != 0)
		{
			return -1;
		}
		req.addr = get_module_base(req.pid, name);
		if (copy_to_user((void __user *)arg, &req, sizeof(req)) != 0)
		{
			return -1;
		}
		break;
	}
	default:
		return -1;
	}
	return 0;
}

static long teargame_fd_ioctl(struct file *file, unsigned int cmd, unsigned long arg)
{
	struct teargame_fd_ctx *ctx = file->private_data;

	if (cmd == DRA_IOCTL_REQUEST)
		return teargame_ioctl_request(ctx, (void __user *)arg);
	if (cmd == DRA_HWBP_INFO || cmd == DRA_HWBP_SET ||
		cmd == DRA_HWBP_GET || cmd == DRA_HWBP_REMOVE)
		return teargame_ioctl_hwbp(ctx, cmd, arg);
	if (cmd == DRA_TOUCH_INIT || cmd == DRA_TOUCH_DOWN ||
		cmd == DRA_TOUCH_MOVE || cmd == DRA_TOUCH_UP)
		return teargame_ioctl_touch(cmd, arg);
	if (cmd == DRA_GYRO_CONFIG)
		return teargame_ioctl_gyro(arg);
	if (cmd == DRA_HIDE_SELF || cmd == DRA_UNHIDE_SELF)
		return teargame_ioctl_hide(ctx, cmd);

	return teargame_dispatch_cmd(cmd, arg);
}

static int teargame_fd_release(struct inode *inode, struct file *file)
{
	struct teargame_fd_ctx *ctx = file->private_data;

	(void)inode;
	if (ctx)
	{
		mutex_lock(&ctx->lock);
		teargame_cleanup_ctx_locked(ctx);
		mutex_unlock(&ctx->lock);
		kfree(ctx);
		file->private_data = NULL;
	}
	return 0;
}

static const struct file_operations teargame_fops = {
	.owner = THIS_MODULE,
	.unlocked_ioctl = teargame_fd_ioctl,
#ifdef CONFIG_COMPAT
	.compat_ioctl = teargame_fd_ioctl,
#endif
	.release = teargame_fd_release,
};

static int teargame_install_fd_to_user(int __user *outp)
{
	struct teargame_fd_ctx *ctx;
	struct file *filp;
	int fd;

	if (!outp)
		return -EINVAL;

	ctx = kzalloc(sizeof(*ctx), GFP_KERNEL);
	if (!ctx)
		return -ENOMEM;
	mutex_init(&ctx->lock);
	ctx->owner_tgid = current->tgid;

	fd = get_unused_fd_flags(O_CLOEXEC);
	if (fd < 0)
	{
		kfree(ctx);
		return fd;
	}

	filp = anon_inode_getfile(TEARGAME_FD_NAME, &teargame_fops, ctx, O_RDWR | O_CLOEXEC);
	if (IS_ERR(filp))
	{
		int ret = PTR_ERR(filp);
		put_unused_fd(fd);
		kfree(ctx);
		return ret;
	}

	if (copy_to_user(outp, &fd, sizeof(fd)))
	{
		put_unused_fd(fd);
		fput(filp);
		return -EFAULT;
	}

	fd_install(fd, filp);
	return fd;
}

static void teargame_install_fd_work_func(struct callback_head *cb)
{
	struct teargame_install_fd_work *work = container_of(cb, struct teargame_install_fd_work, cb);
	int fd = teargame_install_fd_to_user(work->outp);

	if (fd < 0 && work->outp && copy_to_user(work->outp, &fd, sizeof(fd)))
		pr_debug("[DraKernel] failed to copy fd install error: %d\n", fd);

	kfree(work);
}

static int teargame_prctl_handler_pre(struct kprobe *p, struct pt_regs *regs)
{
	struct pt_regs *real_regs = TEARGAME_PT_REAL_REGS(regs);
	unsigned long option = TEARGAME_PT_REGS_ARG1(real_regs);
	unsigned long cmd = TEARGAME_PT_REGS_ARG2(real_regs);
	unsigned long arg3 = TEARGAME_PT_REGS_ARG3(real_regs);

	(void)p;

	if (option != KERNEL_SU_OPTION)
		return 0;

	if (cmd == OP_INIT_KEY)
	{
		struct teargame_install_fd_work *work;

		work = kzalloc(sizeof(*work), GFP_ATOMIC);
		if (!work)
			return 0;

		work->outp = (int __user *)arg3;
		work->cb.func = teargame_install_fd_work_func;

		if (!fn_task_work_add || fn_task_work_add(current, &work->cb, TWA_RESUME))
			kfree(work);
	}

	return 0;
}

static struct kprobe teargame_prctl_kp = {
	.symbol_name = TEARGAME_PRCTL_SYMBOL,
	.pre_handler = teargame_prctl_handler_pre,
};

int __init driver_entry(void)
{
	int ret;
	printk(KERN_INFO "=============================================\n");
	printk(KERN_INFO "[DraKernel] Driver loading...\n");
	printk(KERN_INFO "[DraKernel] Author: 泪心 (Tear)\n");
	printk(KERN_INFO "[DraKernel] QQ: 2254013571\n");
	printk(KERN_INFO "[DraKernel] Email: tearhacker@outlook.com\n");
	printk(KERN_INFO "[DraKernel] Telegram: t.me/TearGame\n");
	printk(KERN_INFO "[DraKernel] GitHub: github.com/tearhacker\n");
	printk(KERN_INFO "=============================================\n");

	fn_task_work_add = (void *)teargame_lookup_symbol("task_work_add");
	if (!fn_task_work_add) {
		printk(KERN_ERR "[DraKernel] Failed to resolve task_work_add\n");
		return -ENOENT;
	}

	fn_aarch64_insn_patch_text = (void *)teargame_lookup_symbol("aarch64_insn_patch_text");
	if (!fn_aarch64_insn_patch_text) {
		printk(KERN_ERR "[DraKernel] Failed to resolve aarch64_insn_patch_text\n");
		return -ENOENT;
	}

	ret = linyu_gyro_init();
	if (ret)
		printk(KERN_WARNING "[DraKernel] Gyro hook init failed ret=%d\n", ret);
	
	ret = register_kprobe(&teargame_prctl_kp);
	if (ret == 0) {
		printk(KERN_INFO "[DraKernel] KernelSU prctl bridge registered\n");
		teargame_hide_module_visibility();
		printk(KERN_INFO "[DraKernel] Driver loaded successfully!\n");
	} else {
		printk(KERN_ERR "[DraKernel] Failed to register prctl bridge! ret=%d\n", ret);
	}
	return ret;
}

void __exit driver_unload(void)
{
	printk(KERN_INFO "[DraKernel] Driver unloading...\n");
	unregister_kprobe(&teargame_prctl_kp);
	mutex_lock(&teargame_touch_lock);
	v_touch_destroy();
	mutex_unlock(&teargame_touch_lock);
	linyu_gyro_exit();
	inline_hook_remove_all();
	printk(KERN_INFO "[DraKernel] KernelSU prctl bridge unregistered\n");
	printk(KERN_INFO "[DraKernel] Goodbye! - by 泪心\n");
}

module_init(driver_entry);
module_exit(driver_unload);

MODULE_DESCRIPTION("DraKernel Memory Driver");
MODULE_LICENSE("GPL");
MODULE_AUTHOR("泪心 QQ:2254013571");
