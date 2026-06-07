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

//原作者JiangNight  源码存在严重问题 加载格机 重启  黑砖    加载失败  kernel pacni 各种问题
//泪心已经彻底修复优化
	//printk(KERN_INFO "[TearGame] QQ: 2254013571\n");
	//printk(KERN_INFO "[TearGame] Email: tearhacker@outlook.com\n");
//printk(KERN_INFO "[TearGame] Telegram: t.me/TearGame\n");
	//(KERN_INFO "[TearGame] GitHub: github.com/tearhacker\n");
	//原项目链接 https://github.com/Jiang-Night/Kernel_driver_hack
	//泪心驱动完整开源读写内核源码新项目链接 https://github.com/tearhacker/TearGame_KernelDriver_Android_WriteReadMemory

	#include "memory.h"
	#include <linux/mm.h>
	#include <linux/slab.h>
	#include <linux/uaccess.h>
	#include <linux/version.h>
	#include <linux/sched/mm.h>
	#include <linux/sched/task.h>
	#include <linux/pid.h>
	#include <linux/vmalloc.h>

	#define TEARGAME_MAX_RW_SIZE (64 * 1024)
	#define TEARGAME_STACK_RW_SIZE 256

	static bool teargame_range_overflow(uintptr_t addr, size_t size)
	{
		return size == 0 || addr == 0 || addr + size < addr;
	}

	static bool teargame_check_vma(struct task_struct *task, uintptr_t addr, size_t size, vm_flags_t need_flags)
	{
		struct mm_struct *mm;
		struct vm_area_struct *vma;
		bool ok = false;
	
		if (!task || teargame_range_overflow(addr, size))
			return false;
	
		mm = get_task_mm(task);
		if (!mm)
			return false;
	
		mmap_read_lock(mm);
		vma = find_vma(mm, addr);
		if (vma && vma->vm_start <= addr && addr + size <= vma->vm_end &&
			((vma->vm_flags & need_flags) == need_flags))
			ok = true;
		mmap_read_unlock(mm);
	
		mmput(mm);
		return ok;
	}
	
	bool read_process_memory(pid_t pid, uintptr_t addr, void *buffer, size_t size)
	{
		struct task_struct *task;
		struct pid *pid_struct;
		int bytes_read;
		unsigned char stack_buf[TEARGAME_STACK_RW_SIZE];
		void *kbuf;
	
		if (teargame_range_overflow(addr, size) || size > TEARGAME_MAX_RW_SIZE)
			return false;
	
		pid_struct = find_get_pid(pid);
		if (!pid_struct)
			return false;
	
		task = get_pid_task(pid_struct, PIDTYPE_PID);
		put_pid(pid_struct);
		if (!task)
			return false;
	
		if (!teargame_check_vma(task, addr, size, VM_READ)) {
			put_task_struct(task);
			return false;
		}
	
		kbuf = (size <= sizeof(stack_buf)) ? stack_buf : kvmalloc(size, GFP_KERNEL);
		if (!kbuf) {
			put_task_struct(task);
			return false;
		}
	
		bytes_read = access_process_vm(task, addr, kbuf, size, 0);
		put_task_struct(task);
	
		if (bytes_read != size) {
			if (kbuf != stack_buf)
				kvfree(kbuf);
			return false;
		}
	
		if (copy_to_user(buffer, kbuf, size)) {
			if (kbuf != stack_buf)
				kvfree(kbuf);
			return false;
		}
	
		if (kbuf != stack_buf)
			kvfree(kbuf);
		return true;
	}
	
	bool write_process_memory(pid_t pid, uintptr_t addr, void *buffer, size_t size)
	{
		struct task_struct *task;
		struct pid *pid_struct;
		int bytes_written;
		unsigned char stack_buf[TEARGAME_STACK_RW_SIZE];
		void *kbuf;
	
		if (teargame_range_overflow(addr, size) || size > TEARGAME_MAX_RW_SIZE)
			return false;
	
		pid_struct = find_get_pid(pid);
		if (!pid_struct)
			return false;
	
		task = get_pid_task(pid_struct, PIDTYPE_PID);
		put_pid(pid_struct);
		if (!task)
			return false;
	
		if (!teargame_check_vma(task, addr, size, VM_WRITE)) {
			put_task_struct(task);
			return false;
		}
	
		kbuf = (size <= sizeof(stack_buf)) ? stack_buf : kvmalloc(size, GFP_KERNEL);
		if (!kbuf) {
			put_task_struct(task);
			return false;
		}
	
		if (copy_from_user(kbuf, buffer, size)) {
			if (kbuf != stack_buf)
				kvfree(kbuf);
			put_task_struct(task);
			return false;
		}
	
		bytes_written = access_process_vm(task, addr, kbuf, size, FOLL_WRITE);
		put_task_struct(task);
		if (kbuf != stack_buf)
			kvfree(kbuf);
	
		return (bytes_written == size);
	}
	
