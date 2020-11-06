/*
 * include/linux/sizes.h
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License version 2 as
 * published by the Free Software Foundation.
 */

/// D translation of sizes.h from btrfs-progs (v5.9)
module btrfs.c.kernel_lib.sizes;

enum SZ_1				= 0x00000001;
enum SZ_2				= 0x00000002;
enum SZ_4				= 0x00000004;
enum SZ_8				= 0x00000008;
enum SZ_16				= 0x00000010;
enum SZ_32				= 0x00000020;
enum SZ_64				= 0x00000040;
enum SZ_128				= 0x00000080;
enum SZ_256				= 0x00000100;
enum SZ_512				= 0x00000200;

enum SZ_1K				= 0x00000400;
enum SZ_2K				= 0x00000800;
enum SZ_4K				= 0x00001000;
enum SZ_8K				= 0x00002000;
enum SZ_16K				= 0x00004000;
enum SZ_32K				= 0x00008000;
enum SZ_64K				= 0x00010000;
enum SZ_128K			= 0x00020000;
enum SZ_256K			= 0x00040000;
enum SZ_512K			= 0x00080000;

enum SZ_1M				= 0x00100000;
enum SZ_2M				= 0x00200000;
enum SZ_4M				= 0x00400000;
enum SZ_8M				= 0x00800000;
enum SZ_16M				= 0x01000000;
enum SZ_32M				= 0x02000000;
enum SZ_64M				= 0x04000000;
enum SZ_128M			= 0x08000000;
enum SZ_256M			= 0x10000000;
enum SZ_512M			= 0x20000000;

enum SZ_1G				= 0x40000000;
enum SZ_2G				= 0x80000000;
