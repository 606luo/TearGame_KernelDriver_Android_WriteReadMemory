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

#include <linux/ioctl.h>

typedef struct _request
{
	pid_t pid;
	uintptr_t addr;
	void *buffer;
	size_t size;
} request, *Prequest;

typedef request COPY_MEMORY, *PCOPY_MEMORY;

#define DRA_MARK 'D'
#define GET_PID _IOW(DRA_MARK, 0, request)
#define MODULE_BASE _IOW(DRA_MARK, 1, request)
#define MODULE_BSS _IOW(DRA_MARK, 3, request)
#define READ_MEM _IOW(DRA_MARK, 4, request)
#define WRITE_MEM _IOW(DRA_MARK, 5, request)
#define DRA_IOCTL_REQUEST _IOC(_IOC_READ | _IOC_WRITE, DRA_MARK, 11, 0)

enum OPERATIONS
{
	OP_INIT_KEY = 0x800,
	OP_READ_MEM = READ_MEM,
	OP_WRITE_MEM = WRITE_MEM,
	OP_MODULE_BASE = MODULE_BASE,
};

#define KERNEL_SU_OPTION 0xDEADBEEF
#define KERNEL_SU_OPTION_REPLY 0xDEADBEEF
