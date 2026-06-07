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
#include <linux/slab.h>
#include <linux/task_work.h>
#include <linux/uaccess.h>
#include "comm.h"
#include "memory.h"
#include "process.h"
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
#error "TearGame only supports arm64"
#endif

#define TEARGAME_FD_NAME "[TearGame]"

struct teargame_install_fd_work
{
	struct callback_head cb;
	int __user *outp;
};

static int (*fn_task_work_add)(struct task_struct *task,
							   struct callback_head *work,
							   enum task_work_notify_mode notify);

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
		MODULE_BASE mb;
		char name[0x100] = {0};
		if (copy_from_user(&mb, (void __user *)arg, sizeof(mb)) != 0 || copy_from_user(name, (void __user *)mb.name, sizeof(name) - 1) != 0)
		{
			return -1;
		}
		mb.base = get_module_base(mb.pid, name);
		if (copy_to_user((void __user *)arg, &mb, sizeof(mb)) != 0)
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
	(void)file;
	return teargame_dispatch_cmd(cmd, arg);
}

static const struct file_operations teargame_fops = {
	.owner = THIS_MODULE,
	.unlocked_ioctl = teargame_fd_ioctl,
#ifdef CONFIG_COMPAT
	.compat_ioctl = teargame_fd_ioctl,
#endif
};

static int teargame_install_fd_to_user(int __user *outp)
{
	struct file *filp;
	int fd;

	if (!outp)
		return -EINVAL;

	fd = get_unused_fd_flags(O_CLOEXEC);
	if (fd < 0)
		return fd;

	filp = anon_inode_getfile(TEARGAME_FD_NAME, &teargame_fops, NULL, O_RDWR | O_CLOEXEC);
	if (IS_ERR(filp))
	{
		int ret = PTR_ERR(filp);
		put_unused_fd(fd);
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
		pr_debug("[TearGame] failed to copy fd install error: %d\n", fd);

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
	printk(KERN_INFO "[TearGame] Driver loading...\n");
	printk(KERN_INFO "[TearGame] Author: 泪心 (Tear)\n");
	printk(KERN_INFO "[TearGame] QQ: 2254013571\n");
	printk(KERN_INFO "[TearGame] Email: tearhacker@outlook.com\n");
	printk(KERN_INFO "[TearGame] Telegram: t.me/TearGame\n");
	printk(KERN_INFO "[TearGame] GitHub: github.com/tearhacker\n");
	printk(KERN_INFO "=============================================\n");

	fn_task_work_add = (void *)teargame_lookup_symbol("task_work_add");
	if (!fn_task_work_add) {
		printk(KERN_ERR "[TearGame] Failed to resolve task_work_add\n");
		return -ENOENT;
	}
	
	ret = register_kprobe(&teargame_prctl_kp);
	if (ret == 0) {
		printk(KERN_INFO "[TearGame] KernelSU prctl bridge registered\n");
		printk(KERN_INFO "[TearGame] Driver loaded successfully!\n");
	} else {
		printk(KERN_ERR "[TearGame] Failed to register prctl bridge! ret=%d\n", ret);
	}
	return ret;
}

void __exit driver_unload(void)
{
	printk(KERN_INFO "[TearGame] Driver unloading...\n");
	unregister_kprobe(&teargame_prctl_kp);
	printk(KERN_INFO "[TearGame] KernelSU prctl bridge unregistered\n");
	printk(KERN_INFO "[TearGame] Goodbye! - by 泪心\n");
}

module_init(driver_entry);
module_exit(driver_unload);

MODULE_DESCRIPTION("TearGame Memory Driver - t.me/TearGame");
MODULE_LICENSE("GPL");
MODULE_AUTHOR("泪心 QQ:2254013571");
