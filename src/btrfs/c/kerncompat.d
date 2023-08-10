/*
 * Copyright (C) 2007 Oracle.  All rights reserved.
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public
 * License v2 as published by the Free Software Foundation.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * General Public License for more details.
 *
 * You should have received a copy of the GNU General Public
 * License along with this program; if not, write to the
 * Free Software Foundation, Inc., 59 Temple Place - Suite 330,
 * Boston, MA 021110-1307, USA.
 */

/// D translation of kerncompat.h from btrfs-progs (v5.9)
module btrfs.c.kerncompat;

import btrfs.c.dcompat;

import core.stdc.config;
import core.stdc.stdint;
import core.stdc.stdlib;

auto ptr_to_u64(T)(T x) { return cast(u64)cast(uintptr_t)x; }
auto u64_to_ptr(T)(T x) { return cast(void *)cast(uintptr_t)x; }

enum READ = 0;
enum WRITE = 1;
enum READA = 2;

alias gfp_t = int;
auto get_cpu_var(T)(auto ref T p) { return p; }
auto __get_cpu_var(T)(auto ref T p) { return p; }
enum BITS_PER_BYTE = 8;
enum BITS_PER_LONG = (__SIZEOF_LONG__ * BITS_PER_BYTE);
enum __GFP_BITS_SHIFT = 20;
enum __GFP_BITS_MASK = (cast(int)((1 << __GFP_BITS_SHIFT) - 1));
enum GFP_KERNEL = 0;
enum GFP_NOFS = 0;
auto ARRAY_SIZE(T, size_t n)(ref T[n] x) { return n; }

public import core.stdc.limits : ULONG_MAX;

alias s8 = byte;
alias u8 = ubyte;
alias s16 = short;
alias u16 = ushort;
alias s32 = int;
alias u32 = uint;
alias s64 = long;
alias u64 = ulong;

alias __s8 = s8;
alias __u8 = u8;
alias __s16 = s16;
alias __u16 = u16;
alias __s32 = s32;
alias __u32 = u32;
alias __s64 = s64;
alias __u64 = u64;

struct vma_shared { int prio_tree_node; }
struct vm_area_struct {
	c_ulong vm_pgoff;
	c_ulong vm_start;
	c_ulong vm_end;
	vma_shared shared_;
}

struct page {
	c_ulong index;
}

struct mutex {
	c_ulong lock;
}

void mutex_init()(mutex *m) { m.lock = 1; }

void mutex_lock()(mutex *m)
{
	m.lock--;
}

void mutex_unlock()(mutex *m)
{
	m.lock++;
}

int mutex_is_locked()(mutex *m)
{
	return m.lock != 1;
}

void cond_resched()() {}
void preempt_enable()() {}
void preempt_disable()() {}

auto BITOP_MASK(T)(T nr) { return c_ulong(1) << (nr % BITS_PER_LONG); }
auto BITOP_WORD(T)(T nr) { return nr / BITS_PER_LONG; }

/**
 * __set_bit - Set a bit in memory
 * @nr: the bit to set
 * @addr: the address to start counting from
 *
 * Unlike set_bit(), this function is non-atomic and may be reordered.
 * If it's called on the same region of memory simultaneously, the effect
 * may be that only one operation succeeds.
 */
void __set_bit()(int nr, shared c_ulong *addr)
{
	c_ulong mask = BITOP_MASK(nr);
	c_ulong *p = (cast(c_ulong *)addr) + BITOP_WORD(nr);

	*p  |= mask;
}

void __clear_bit()(int nr, shared c_ulong *addr)
{
	c_ulong mask = BITOP_MASK(nr);
	c_ulong *p = (cast(c_ulong *)addr) + BITOP_WORD(nr);

	*p &= ~mask;
}

/**
 * test_bit - Determine whether a bit is set
 * @nr: bit number to test
 * @addr: Address to start counting from
 */
int test_bit()(int nr, const shared c_ulong *addr)
{
	return 1UL & (addr[BITOP_WORD(nr)] >> (nr & (BITS_PER_LONG-1)));
}

/*
 * error pointer
 */
enum MAX_ERRNO	= 4095;
auto IS_ERR_VALUE(T)(T x) { return (x >= cast(c_ulong)-MAX_ERRNO); }

void *ERR_PTR()(c_long error)
{
	return cast(void *) error;
}

c_long PTR_ERR(const void *ptr)
{
	return cast(c_long) ptr;
}

c_int IS_ERR()(const void *ptr)
{
	return IS_ERR_VALUE(cast(c_ulong)ptr);
}

c_int IS_ERR_OR_NULL()(const void *ptr)
{
	return !ptr || IS_ERR(ptr);
}

auto div_u64(X, Y)(X x, Y y) { return x / y; }

/**
 * __swap - swap values of @a and @b
 * @a: first value
 * @b: second value
 */
void __swap(A, B)(ref A a, ref B b) 
        { typeof(a) __tmp = (a); (a) = (b); (b) = __tmp; }

/*
 * This looks more complex than it should be. But we need to
 * get the type for the ~ right in round_down (it needs to be
 * as wide as the result!), and we want to evaluate the macro
 * arguments just once each.
 */
X __round_mask(X, Y)(X x, Y y) { return cast(X)(y-1); }
auto __round_up(X, Y)(X x, Y y) { return ((x-1) | __round_mask(x, y))+1; }
auto __round_down(X, Y)(X x, Y y) { return x & ~__round_mask(x, y); }

/*
 * printk
 */
void printk(Args...)(const char *fmt, auto ref Args args) { import core.stdc.stdio; fprintf(stderr, fmt, args); }
enum	KERN_CRIT	= "";
enum	KERN_ERR	= "";

/*
 * kmalloc/kfree
 */
auto kmalloc(X, Y)(X x, Y y) { return malloc(x); }
auto kzalloc(X, Y)(X x, Y y) { return calloc(1, x); }
auto kstrdup(X, Y)(X x, Y y) { return strdup(x); }
alias kfree = free;
alias vmalloc = malloc;
alias vfree = free;
alias kvzalloc = kzalloc;
alias kvfree = free;
auto memalloc_nofs_save()() { return 0; }
void memalloc_nofs_restore(X)(X x) {}

// #define container_of(ptr, type, member) ({                      \
//         const typeof( ((type *)0)->member ) *__mptr = (ptr);    \
// 	        (type *)( (char *)__mptr - offsetof(type,member) );})

/* Alignment check */
auto IS_ALIGNED(X, A)(X x, A a) { return (x & (cast(X)a - 1)) == 0; }

c_int is_power_of_2()(c_ulong n)
{
	return (n != 0 && ((n & (n - 1)) == 0));
}

static if (!typesafe) {
alias __le16 = u16;
alias __be16 = u16;
alias __le32 = u32;
alias __be32 = u32;
alias __le64 = u64;
alias __be64 = u64;
} else {
import ae.utils.bitmanip;
alias __le16 = LittleEndian!ushort;
alias __be16 = BigEndian!ushort;
alias __le32 = LittleEndian!uint;
alias __be32 = BigEndian!uint;
alias __le64 = LittleEndian!ulong;
alias __be64 = BigEndian!ulong;
}

/* Macros to generate set/get funcs for the struct fields
 * assume there is a lefoo_to_cpu for every type, so lets make a simple
 * one for u8:
 */
auto le8_to_cpu(V)(V v) { return v; }
auto cpu_to_le8(V)(V v) { return v; }
alias __le8 = u8;

static if (!typesafe) {
// version (BigEndian) {
// #define cpu_to_le64(x) ((__force __le64)(u64)(bswap_64(x)))
// #define le64_to_cpu(x) ((__force u64)(__le64)(bswap_64(x)))
// #define cpu_to_le32(x) ((__force __le32)(u32)(bswap_32(x)))
// #define le32_to_cpu(x) ((__force u32)(__le32)(bswap_32(x)))
// #define cpu_to_le16(x) ((__force __le16)(u16)(bswap_16(x)))
// #define le16_to_cpu(x) ((__force u16)(__le16)(bswap_16(x)))
// } else {
// #define cpu_to_le64(x) ((__force __le64)(u64)(x))
// #define le64_to_cpu(x) ((__force u64)(__le64)(x))
// #define cpu_to_le32(x) ((__force __le32)(u32)(x))
// #define le32_to_cpu(x) ((__force u32)(__le32)(x))
// #define cpu_to_le16(x) ((__force __le16)(u16)(x))
// #define le16_to_cpu(x) ((__force u16)(__le16)(x))
// }
} else {
__le64 cpu_to_le64(u64 x) { return __le64(x); }
u64 le64_to_cpu(const __le64 x) { return x; }
__le32 cpu_to_le32(u32 x) { return __le32(x); }
u32 le32_to_cpu(const __le32 x) { return x; }
__le16 cpu_to_le16(u16 x) { return __le16(x); }
u16 le16_to_cpu(const __le16 x) { return x; }
}

static if (!typesafe) {
align(1) struct __una_u16 { __le16 x; }
align(1) struct __una_u32 { __le32 x; }
align(1) struct __una_u64 { __le64 x; }

auto get_unaligned_le8(P)(P p) { return (*(cast(u8*)(p))); }
auto get_unaligned_8(P)(P p) { return (*(cast(u8*)(p))); }
auto put_unaligned_le8(Val, P)(Val val, P p) { return ((*(cast(u8*)(p))) = (val)); }
auto put_unaligned_8(Val, P)(Val val, P p) { return ((*(cast(u8*)(p))) = (val)); }
auto get_unaligned_le16(P)(P p) { return le16_to_cpu((cast(const __una_u16 *)(p)).x); }
auto get_unaligned_16(P)(P p) { return ((cast(const __una_u16 *)(p)).x); }
auto put_unaligned_le16(Val, P)(Val val, P p) { return ((cast(__una_u16 *)(p)).x = cpu_to_le16(val)); }
auto put_unaligned_16(Val, P)(Val val, P p) { return ((cast(__una_u16 *)(p)).x = (val)); }
auto get_unaligned_le32(P)(P p) { return le32_to_cpu((cast(const __una_u32 *)(p)).x); }
auto get_unaligned_32(P)(P p) { return ((cast(const __una_u32 *)(p)).x); }
auto put_unaligned_le32(Val, P)(Val val, P p) { return ((cast(__una_u32 *)(p)).x = cpu_to_le32(val)); }
auto put_unaligned_32(Val, P)(Val val, P p) { return ((cast(__una_u32 *)(p)).x = (val)); }
auto get_unaligned_le64(P)(P p) { return le64_to_cpu((cast(const __una_u64 *)(p)).x); }
auto get_unaligned_64(P)(P p) { return ((cast(const __una_u64 *)(p)).x); }
auto put_unaligned_le64(Val, P)(Val val, P p) { return ((cast(__una_u64 *)(p)).x = cpu_to_le64(val)); }
auto put_unaligned_64(Val, P)(Val val, P p) { return ((cast(__una_u64 *)(p)).x = (val)); }
} else {
align(1) struct __una_le16 { __le16 x; }
align(1) struct __una_le32 { __le32 x; }
align(1) struct __una_le64 { __le64 x; }
align(1) struct __una_u16 { __u16 x; }
align(1) struct __una_u32 { __u32 x; }
align(1) struct __una_u64 { __u64 x; }

auto get_unaligned_le8(P)(P p) { return (*(cast(u8*)(p))); }
auto get_unaligned_8(P)(P p) { return (*(cast(u8*)(p))); }
auto put_unaligned_le8(Val, P)(Val val, P p) { return ((*(cast(u8*)(p))) = (val)); }
auto put_unaligned_8(Val, P)(Val val, P p) { return ((*(cast(u8*)(p))) = (val)); }
auto get_unaligned_le16(P)(P p) { return le16_to_cpu((cast(const __una_le16 *)(p)).x); }
auto get_unaligned_16(P)(P p) { return ((cast(const __una_u16 *)(p)).x); }
auto put_unaligned_le16(Val, P)(Val val, P p) { return ((cast(__una_le16 *)(p)).x = cpu_to_le16(val)); }
auto put_unaligned_16(Val, P)(Val val, P p) { return ((cast(__una_u16 *)(p)).x = (val)); }
auto get_unaligned_le32(P)(P p) { return le32_to_cpu((cast(const __una_le32 *)(p)).x); }
auto get_unaligned_32(P)(P p) { return ((cast(const __una_u32 *)(p)).x); }
auto put_unaligned_le32(Val, P)(Val val, P p) { return ((cast(__una_le32 *)(p)).x = cpu_to_le32(val)); }
auto put_unaligned_32(Val, P)(Val val, P p) { return ((cast(__una_u32 *)(p)).x = (val)); }
auto get_unaligned_le64(P)(P p) { return le64_to_cpu((cast(const __una_le64 *)(p)).x); }
auto get_unaligned_64(P)(P p) { return ((cast(const __una_u64 *)(p)).x); }
auto put_unaligned_le64(Val, P)(Val val, P p) { return ((cast(__una_le64 *)(p)).x = cpu_to_le64(val)); }
auto put_unaligned_64(Val, P)(Val val, P p) { return ((cast(__una_u64 *)(p)).x = (val)); }
}
