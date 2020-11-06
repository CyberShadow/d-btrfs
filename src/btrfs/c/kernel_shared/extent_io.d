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

/// D translation of extent_io.h from btrfs-progs (v5.9)
module btrfs.c.kernel_shared.extent_io;

import core.stdc.config;

import btrfs.c.kerncompat;
import btrfs.c.kernel_lib.list;
import btrfs.c.common.extent_cache;

import btrfs.c.kernel_shared.ctree : btrfs_fs_info;

enum EXTENT_DIRTY		= 1U << 0;
enum EXTENT_WRITEBACK	= 1U << 1;
enum EXTENT_UPTODATE		= 1U << 2;
enum EXTENT_LOCKED		= 1U << 3;
enum EXTENT_NEW		= 1U << 4;
enum EXTENT_DELALLOC		= 1U << 5;
enum EXTENT_DEFRAG		= 1U << 6;
enum EXTENT_DEFRAG_DONE	= 1U << 7;
enum EXTENT_BUFFER_FILLED	= 1U << 8;
enum EXTENT_CSUM		= 1U << 9;
enum EXTENT_BAD_TRANSID	= 1U << 10;
enum EXTENT_BUFFER_DUMMY	= 1U << 11;
enum EXTENT_IOBITS = EXTENT_LOCKED | EXTENT_WRITEBACK;

enum BLOCK_GROUP_DATA	= 1U << 1;
enum BLOCK_GROUP_METADATA	= 1U << 2;
enum BLOCK_GROUP_SYSTEM	= 1U << 4;

/*
 * The extent buffer bitmap operations are done with byte granularity instead of
 * word granularity for two reasons:
 * 1. The bitmaps must be little-endian on disk.
 * 2. Bitmap items are not guaranteed to be aligned to a word and therefore a
 *    single word in a bitmap may straddle two pages in the extent buffer.
 */
auto BIT_BYTE(T)(T nr) { return nr / BITS_PER_BYTE; }
enum BYTE_MASK = (1 << BITS_PER_BYTE) - 1;
auto BITMAP_FIRST_BYTE_MASK(T)(T start) { return
	((BYTE_MASK << ((start) & (BITS_PER_BYTE - 1))) & BYTE_MASK); }
auto BITMAP_LAST_BYTE_MASK(T)(T nbits) { return 
	(BYTE_MASK >> (-(nbits) & (BITS_PER_BYTE - 1))); }

int le_test_bit(int nr, const u8 *addr)
{
	return 1U & (addr[BIT_BYTE(nr)] >> (nr & (BITS_PER_BYTE-1)));
}

struct extent_io_tree {
	cache_tree state;
	cache_tree cache;
	list_head lru;
	u64 cache_size;
	u64 max_cache_size;
}

struct extent_state {
	cache_extent cache_node;
	u64 start;
	u64 end;
	int refs;
	c_ulong state;
	u64 xprivate;
}

struct extent_buffer {
	cache_extent cache_node;
	u64 start;
	u64 dev_bytenr;
	list_head lru;
	list_head recow;
	u32 len;
	int refs;
	u32 flags;
	int fd;
	btrfs_fs_info *fs_info;
	align(8) char[0] data;
}

void extent_buffer_get()(extent_buffer *eb)
{
	eb.refs++;
}

void extent_io_tree_init(extent_io_tree *tree);
void extent_io_tree_init_cache_max(extent_io_tree *tree,
				   u64 max_cache_size);
void extent_io_tree_cleanup(extent_io_tree *tree);
int set_extent_bits(extent_io_tree *tree, u64 start, u64 end, int bits);
int clear_extent_bits(extent_io_tree *tree, u64 start, u64 end, int bits);
int find_first_extent_bit(extent_io_tree *tree, u64 start,
			  u64 *start_ret, u64 *end_ret, int bits);
int test_range_bit(extent_io_tree *tree, u64 start, u64 end,
		   int bits, int filled);
int set_extent_dirty(extent_io_tree *tree, u64 start, u64 end);
int clear_extent_dirty(extent_io_tree *tree, u64 start, u64 end);
int set_extent_buffer_uptodate(extent_buffer *eb)
{
	eb.flags |= EXTENT_UPTODATE;
	return 0;
}

int clear_extent_buffer_uptodate(extent_buffer *eb)
{
	eb.flags &= ~EXTENT_UPTODATE;
	return 0;
}

int extent_buffer_uptodate(extent_buffer *eb)
{
	if (!eb || IS_ERR(eb))
		return 0;
	if (eb.flags & EXTENT_UPTODATE)
		return 1;
	return 0;
}

int set_state_private(extent_io_tree *tree, u64 start, u64 xprivate);
int get_state_private(extent_io_tree *tree, u64 start, u64 *xprivate);
extent_buffer *find_extent_buffer(extent_io_tree *tree,
					 u64 bytenr, u32 blocksize);
extent_buffer *find_first_extent_buffer(extent_io_tree *tree,
					       u64 start);
extent_buffer *alloc_extent_buffer(btrfs_fs_info *fs_info,
					  u64 bytenr, u32 blocksize);
extent_buffer *btrfs_clone_extent_buffer(extent_buffer *src);
extent_buffer *alloc_dummy_extent_buffer(btrfs_fs_info *fs_info,
						u64 bytenr, u32 blocksize);
void free_extent_buffer(extent_buffer *eb);
void free_extent_buffer_nocache(extent_buffer *eb);
int read_extent_from_disk(extent_buffer *eb,
			  c_ulong offset, ulong len);
int write_extent_to_disk(extent_buffer *eb);
int memcmp_extent_buffer(const extent_buffer *eb, const void *ptrv,
			 c_ulong start, c_ulong len);
void read_extent_buffer(const extent_buffer *eb, void *dst,
			c_ulong start, c_ulong len);
void write_extent_buffer(extent_buffer *eb, const void *src,
			 c_ulong start, c_ulong len);
void copy_extent_buffer(extent_buffer *dst, extent_buffer *src,
			c_ulong dst_offset, c_ulong src_offset,
			c_ulong len);
void memmove_extent_buffer(extent_buffer *dst, c_ulong dst_offset,
			   c_ulong src_offset, c_ulong len);
void memset_extent_buffer(extent_buffer *eb, char c,
			  c_ulong start, c_ulong len);
int extent_buffer_test_bit(extent_buffer *eb, c_ulong start,
			   c_ulong nr);
int set_extent_buffer_dirty(extent_buffer *eb);
int clear_extent_buffer_dirty(extent_buffer *eb);
int read_data_from_disk(btrfs_fs_info *info, void *buf, u64 offset,
			u64 bytes, int mirror);
int write_data_to_disk(btrfs_fs_info *info, void *buf, u64 offset,
		       u64 bytes, int mirror);
void extent_buffer_bitmap_clear(extent_buffer *eb, c_ulong start,
                                c_ulong pos, c_ulong len);
void extent_buffer_bitmap_set(extent_buffer *eb, c_ulong start,
                              c_ulong pos, c_ulong len);
