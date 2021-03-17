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

/// D translation of ctree.h from btrfs-progs (v5.9)
module btrfs.c.kernel_shared.ctree;

import std.bitmanip;

import btrfs.c.dcompat;
import btrfs.c.kerncompat;
import btrfs.c.kernel_lib.list;
import btrfs.c.kernel_lib.rbtree;
import btrfs.c.kernel_lib.sizes;

import btrfs.c.common.extent_cache;
import btrfs.c.kernel_shared.extent_io;
import btrfs.c.ioctl;

struct btrfs_trans_handle;
struct btrfs_free_space_ctl;
enum BTRFS_MAGIC = 0x4D5F53665248425FUL /* ascii _BHRfS_M, no null */;
/*
 * Fake signature for an unfinalized filesystem, which only has barebone tree
 * structures (normally 6 near empty trees, on SINGLE meta/sys temporary chunks)
 *
 * ascii !BHRfS_M, no null
 */
enum BTRFS_MAGIC_TEMPORARY = 0x4D5F536652484221UL;
enum BTRFS_MAX_MIRRORS = 3;
enum BTRFS_MAX_LEVEL = 8;
/* holds pointers to all of the tree roots */
enum BTRFS_ROOT_TREE_OBJECTID = 1UL;
/* stores information about which extents are in use, and reference counts */
enum BTRFS_EXTENT_TREE_OBJECTID = 2UL;
/*
 * chunk tree stores translations from logical -> physical block numbering
 * the super block points to the chunk tree
 */
enum BTRFS_CHUNK_TREE_OBJECTID = 3UL;
/*
 * stores information about which areas of a given device are in use.
 * one per device.  The tree of tree roots points to the device tree
 */
enum BTRFS_DEV_TREE_OBJECTID = 4UL;
/* one per subvolume, storing files and directories */
enum BTRFS_FS_TREE_OBJECTID = 5UL;
/* directory objectid inside the root tree */
enum BTRFS_ROOT_TREE_DIR_OBJECTID = 6UL;
/* holds checksums of all the data extents */
enum BTRFS_CSUM_TREE_OBJECTID = 7UL;
enum BTRFS_QUOTA_TREE_OBJECTID = 8UL;
/* for storing items that use the BTRFS_UUID_KEY* */
enum BTRFS_UUID_TREE_OBJECTID = 9UL;
/* tracks free space in block groups. */
enum BTRFS_FREE_SPACE_TREE_OBJECTID = 10UL;
/* device stats in the device tree */
enum BTRFS_DEV_STATS_OBJECTID = 0UL;
/* for storing balance parameters in the root tree */
enum BTRFS_BALANCE_OBJECTID = -4UL;
/* orphan objectid for tracking unlinked/truncated files */
enum BTRFS_ORPHAN_OBJECTID = -5UL;
/* does write ahead logging to speed up fsyncs */
enum BTRFS_TREE_LOG_OBJECTID = -6UL;
enum BTRFS_TREE_LOG_FIXUP_OBJECTID = -7UL;
/* space balancing */
enum BTRFS_TREE_RELOC_OBJECTID = -8UL;
enum BTRFS_DATA_RELOC_TREE_OBJECTID = -9UL;
/*
 * extent checksums all have this objectid
 * this allows them to share the logging tree
 * for fsyncs
 */
enum BTRFS_EXTENT_CSUM_OBJECTID = -10UL;
/* For storing free space cache */
enum BTRFS_FREE_SPACE_OBJECTID = -11UL;
/*
 * The inode number assigned to the special inode for storing
 * free ino cache
 */
enum BTRFS_FREE_INO_OBJECTID = -12UL;
/* dummy objectid represents multiple objectids */
enum BTRFS_MULTIPLE_OBJECTIDS = -255UL;
/*
 * All files have objectids in this range.
 */
enum BTRFS_FIRST_FREE_OBJECTID = 256UL;
enum BTRFS_LAST_FREE_OBJECTID = -256UL;
enum BTRFS_FIRST_CHUNK_TREE_OBJECTID = 256UL;


/*
 * the device items go into the chunk tree.  The key is in the form
 * [ 1 BTRFS_DEV_ITEM_KEY device_id ]
 */
enum BTRFS_DEV_ITEMS_OBJECTID = 1UL;
enum BTRFS_EMPTY_SUBVOL_DIR_OBJECTID = 2UL;
/*
 * the max metadata block size.  This limit is somewhat artificial,
 * but the memmove costs go through the roof for larger blocks.
 */
enum BTRFS_MAX_METADATA_BLOCKSIZE = 65536;
/*
 * we can actually store much bigger names, but lets not confuse the rest
 * of linux
 */
enum BTRFS_NAME_LEN = 255;
/*
 * Theoretical limit is larger, but we keep this down to a sane
 * value. That should limit greatly the possibility of collisions on
 * inode ref items.
 */
enum	BTRFS_LINK_MAX	= 65535U;

/* 32 bytes in various csum fields */
enum BTRFS_CSUM_SIZE = 32;
/* csum types */
enum btrfs_csum_type {
	BTRFS_CSUM_TYPE_CRC32		= 0,
	BTRFS_CSUM_TYPE_XXHASH		= 1,
	BTRFS_CSUM_TYPE_SHA256		= 2,
	BTRFS_CSUM_TYPE_BLAKE2		= 3,
}

enum BTRFS_EMPTY_DIR_SIZE = 0;
enum BTRFS_FT_UNKNOWN	= 0;
enum BTRFS_FT_REG_FILE	= 1;
enum BTRFS_FT_DIR		= 2;
enum BTRFS_FT_CHRDEV		= 3;
enum BTRFS_FT_BLKDEV		= 4;
enum BTRFS_FT_FIFO		= 5;
enum BTRFS_FT_SOCK		= 6;
enum BTRFS_FT_SYMLINK	= 7;
enum BTRFS_FT_XATTR		= 8;
enum BTRFS_FT_MAX		= 9;
enum BTRFS_ROOT_SUBVOL_RDONLY	= (1UL << 0);
/*
 * the key defines the order in the tree, and so it also defines (optimal)
 * block layout.  objectid corresponds to the inode number.  The flags
 * tells us things about the object, and is a kind of stream selector.
 * so for a given inode, keys with flags of 1 might refer to the inode
 * data, flags of 2 may point to file data in the btree and flags == 3
 * may point to extents.
 *
 * offset is the starting byte offset for this key in the stream.
 *
 * btrfs_disk_key is in disk byte order.  struct btrfs_key is always
 * in cpu native order.  Otherwise they are identical and their sizes
 * should be the same (ie both packed)
 */
struct btrfs_disk_key {
align(1):
	__le64 objectid;
	u8 type;
	__le64 offset;
}

struct btrfs_key {
align(1):
	u64 objectid;
	u8 type;
	u64 offset;
}

struct btrfs_mapping_tree {
	.cache_tree cache_tree;
}

enum BTRFS_UUID_SIZE = 16;
struct btrfs_dev_item {
align(1):
	/* the internal btrfs device id */
	__le64 devid;

	/* size of the device */
	__le64 total_bytes;

	/* bytes used */
	__le64 bytes_used;

	/* optimal io alignment for this device */
	__le32 io_align;

	/* optimal io width for this device */
	__le32 io_width;

	/* minimal io size for this device */
	__le32 sector_size;

	/* type and info about this device */
	__le64 type;

	/* expected generation for this device */
	__le64 generation;

	/*
	 * starting byte of this partition on the device,
	 * to allow for stripe alignment in the future
	 */
	__le64 start_offset;

	/* grouping information for allocation decisions */
	__le32 dev_group;

	/* seek speed 0-100 where 100 is fastest */
	u8 seek_speed;

	/* bandwidth 0-100 where 100 is fastest */
	u8 bandwidth;

	/* btrfs generated uuid for this device */
	u8[BTRFS_UUID_SIZE] uuid;

	/* uuid of FS who owns this device */
	u8[BTRFS_UUID_SIZE] fsid;
}

struct btrfs_stripe {
align(1):
	__le64 devid;
	__le64 offset;
	u8[BTRFS_UUID_SIZE] dev_uuid;
}

struct btrfs_chunk {
align(1):
	/* size of this chunk in bytes */
	__le64 length;

	/* objectid of the root referencing this chunk */
	__le64 owner;

	__le64 stripe_len;
	__le64 type;

	/* optimal io alignment for this chunk */
	__le32 io_align;

	/* optimal io width for this chunk */
	__le32 io_width;

	/* minimal io size for this chunk */
	__le32 sector_size;

	/* 2^16 stripes is quite a lot, a second limit is the size of a single
	 * item in the btree
	 */
	__le16 num_stripes;

	/* sub stripes only matter for raid10 */
	__le16 sub_stripes;
	btrfs_stripe[0] stripe;
	/* additional stripes go here */
}

enum BTRFS_FREE_SPACE_EXTENT	= 1;
enum BTRFS_FREE_SPACE_BITMAP	= 2;
struct btrfs_free_space_entry {
	__le64 offset;
	__le64 bytes;
	u8 type;
}

struct btrfs_free_space_header {
	btrfs_disk_key location;
	__le64 generation;
	__le64 num_entries;
	__le64 num_bitmaps;
}

ulong btrfs_chunk_item_size(int num_stripes)
{
	assert(num_stripes != 0);
	return btrfs_chunk.sizeof +
		btrfs_stripe.sizeof * (num_stripes - 1);
}

enum BTRFS_HEADER_FLAG_WRITTEN		= (1UL << 0);
enum BTRFS_HEADER_FLAG_RELOC			= (1UL << 1);
enum BTRFS_SUPER_FLAG_SEEDING		= (1UL << 32);
enum BTRFS_SUPER_FLAG_METADUMP		= (1UL << 33);
enum BTRFS_SUPER_FLAG_METADUMP_V2		= (1UL << 34);
enum BTRFS_SUPER_FLAG_CHANGING_FSID		= (1UL << 35);
enum BTRFS_SUPER_FLAG_CHANGING_FSID_V2	= (1UL << 36);
enum BTRFS_BACKREF_REV_MAX		= 256;
enum BTRFS_BACKREF_REV_SHIFT		= 56;
enum BTRFS_BACKREF_REV_MASK		= ((cast(u64)BTRFS_BACKREF_REV_MAX - 1) <<
					 BTRFS_BACKREF_REV_SHIFT);
enum BTRFS_OLD_BACKREF_REV		= 0;
enum BTRFS_MIXED_BACKREF_REV		= 1;
/*
 * every tree block (leaf or node) starts with this header.
 */
struct btrfs_header {
align(1):
	/* these first four must match the super block */
	u8[BTRFS_CSUM_SIZE] csum;
	u8[BTRFS_FSID_SIZE] fsid; /* FS specific uuid */
	__le64 bytenr; /* which block this node is supposed to live in */
	__le64 flags;

	/* allowed to be different from the super from here on down */
	u8[BTRFS_UUID_SIZE] chunk_tree_uuid;
	__le64 generation;
	__le64 owner;
	__le32 nritems;
	u8 level;
}

auto __BTRFS_LEAF_DATA_SIZE(T)(T bs) { return bs - btrfs_header.sizeof; }
auto BTRFS_LEAF_DATA_SIZE(T)(T fs_info) { return
				(__BTRFS_LEAF_DATA_SIZE(fs_info.nodesize)); }

/*
 * this is a very generous portion of the super block, giving us
 * room to translate 14 chunks with 3 stripes each.
 */
enum BTRFS_SYSTEM_CHUNK_ARRAY_SIZE = 2048;
enum BTRFS_LABEL_SIZE = 256;
/*
 * just in case we somehow lose the roots and are not able to mount,
 * we store an array of the roots from previous transactions
 * in the super.
 */
enum BTRFS_NUM_BACKUP_ROOTS = 4;
struct btrfs_root_backup {
align(1):
	__le64 tree_root;
	__le64 tree_root_gen;

	__le64 chunk_root;
	__le64 chunk_root_gen;

	__le64 extent_root;
	__le64 extent_root_gen;

	__le64 fs_root;
	__le64 fs_root_gen;

	__le64 dev_root;
	__le64 dev_root_gen;

	__le64 csum_root;
	__le64 csum_root_gen;

	__le64 total_bytes;
	__le64 bytes_used;
	__le64 num_devices;
	/* future */
	__le64[4] unsed_64;

	u8 tree_root_level;
	u8 chunk_root_level;
	u8 extent_root_level;
	u8 fs_root_level;
	u8 dev_root_level;
	u8 csum_root_level;
	/* future and to align */
	u8[10] unused_8;
}

/*
 * the super block basically lists the main trees of the FS
 * it currently lacks any block count etc etc
 */
struct btrfs_super_block {
align(1):
	u8[BTRFS_CSUM_SIZE] csum;
	/* the first 3 fields must match struct btrfs_header */
	u8[BTRFS_FSID_SIZE] fsid;    /* FS specific uuid */
	__le64 bytenr; /* this block number */
	__le64 flags;

	/* allowed to be different from the btrfs_header from here own down */
	__le64 magic;
	__le64 generation;
	__le64 root;
	__le64 chunk_root;
	__le64 log_root;

	/* this will help find the new super based on the log root */
	__le64 log_root_transid;
	__le64 total_bytes;
	__le64 bytes_used;
	__le64 root_dir_objectid;
	__le64 num_devices;
	__le32 sectorsize;
	__le32 nodesize;
	/* Unused and must be equal to nodesize */
	__le32 __unused_leafsize;
	__le32 stripesize;
	__le32 sys_chunk_array_size;
	__le64 chunk_root_generation;
	__le64 compat_flags;
	__le64 compat_ro_flags;
	__le64 incompat_flags;
	__le16 csum_type;
	u8 root_level;
	u8 chunk_root_level;
	u8 log_root_level;
	btrfs_dev_item dev_item;

	char[BTRFS_LABEL_SIZE] label;

	__le64 cache_generation;
	__le64 uuid_tree_generation;

	u8[BTRFS_FSID_SIZE] metadata_uuid;
	/* future expansion */
	__le64[28] reserved;
	u8[BTRFS_SYSTEM_CHUNK_ARRAY_SIZE] sys_chunk_array;
	btrfs_root_backup[BTRFS_NUM_BACKUP_ROOTS] super_roots;
}

/*
 * Compat flags that we support.  If any incompat flags are set other than the
 * ones specified below then we will fail to mount
 */
enum BTRFS_FEATURE_COMPAT_RO_FREE_SPACE_TREE	= (1UL << 0);
/*
 * Older kernels on big-endian systems produced broken free space tree bitmaps,
 * and btrfs-progs also used to corrupt the free space tree. If this bit is
 * clear, then the free space tree cannot be trusted. btrfs-progs can also
 * intentionally clear this bit to ask the kernel to rebuild the free space
 * tree.
 */
enum BTRFS_FEATURE_COMPAT_RO_FREE_SPACE_TREE_VALID	= (1UL << 1);
enum BTRFS_FEATURE_INCOMPAT_MIXED_BACKREF	= (1UL << 0);
enum BTRFS_FEATURE_INCOMPAT_DEFAULT_SUBVOL	= (1UL << 1);
enum BTRFS_FEATURE_INCOMPAT_MIXED_GROUPS	= (1UL << 2);
enum BTRFS_FEATURE_INCOMPAT_COMPRESS_LZO	= (1UL << 3);
enum BTRFS_FEATURE_INCOMPAT_COMPRESS_ZSTD	= (1UL << 4);
/*
 * older kernels tried to do bigger metadata blocks, but the
 * code was pretty buggy.  Lets not let them try anymore.
 */
enum BTRFS_FEATURE_INCOMPAT_BIG_METADATA     = (1UL << 5);
enum BTRFS_FEATURE_INCOMPAT_EXTENDED_IREF	= (1UL << 6);
enum BTRFS_FEATURE_INCOMPAT_RAID56		= (1UL << 7);
enum BTRFS_FEATURE_INCOMPAT_SKINNY_METADATA	= (1UL << 8);
enum BTRFS_FEATURE_INCOMPAT_NO_HOLES		= (1UL << 9);
enum BTRFS_FEATURE_INCOMPAT_METADATA_UUID    = (1UL << 10);
enum BTRFS_FEATURE_INCOMPAT_RAID1C34		= (1UL << 11);
enum BTRFS_FEATURE_COMPAT_SUPP		= 0UL;
/*
 * The FREE_SPACE_TREE and FREE_SPACE_TREE_VALID compat_ro bits must not be
 * added here until read-write support for the free space tree is implemented in
 * btrfs-progs.
 */
enum BTRFS_FEATURE_COMPAT_RO_SUPP			=
	(BTRFS_FEATURE_COMPAT_RO_FREE_SPACE_TREE |
	 BTRFS_FEATURE_COMPAT_RO_FREE_SPACE_TREE_VALID);
enum BTRFS_FEATURE_INCOMPAT_SUPP			=
	(BTRFS_FEATURE_INCOMPAT_MIXED_BACKREF |
	 BTRFS_FEATURE_INCOMPAT_DEFAULT_SUBVOL |
	 BTRFS_FEATURE_INCOMPAT_COMPRESS_LZO |
	 BTRFS_FEATURE_INCOMPAT_COMPRESS_ZSTD |
	 BTRFS_FEATURE_INCOMPAT_BIG_METADATA |
	 BTRFS_FEATURE_INCOMPAT_EXTENDED_IREF |
	 BTRFS_FEATURE_INCOMPAT_RAID56 |
	 BTRFS_FEATURE_INCOMPAT_MIXED_GROUPS |
	 BTRFS_FEATURE_INCOMPAT_SKINNY_METADATA |
	 BTRFS_FEATURE_INCOMPAT_NO_HOLES |
	 BTRFS_FEATURE_INCOMPAT_RAID1C34 |
	 BTRFS_FEATURE_INCOMPAT_METADATA_UUID);
/*
 * A leaf is full of items. offset and size tell us where to find
 * the item in the leaf (relative to the start of the data area)
 */
struct btrfs_item {
	align(1):
	btrfs_disk_key key;
	__le32 offset;
	__le32 size;
}

/*
 * leaves have an item area and a data area:
 * [item0, item1....itemN] [free space] [dataN...data1, data0]
 *
 * The data is separate from the items to get the keys closer together
 * during searches.
 */
struct btrfs_leaf {
align(1):
	btrfs_header header;
	btrfs_item[0] items;
}

/*
 * all non-leaf blocks are nodes, they hold only keys and pointers to
 * other blocks
 */
struct btrfs_key_ptr {
align(1):
	btrfs_disk_key key;
	__le64 blockptr;
	__le64 generation;
}

struct btrfs_node {
align(1):
	btrfs_header header;
	btrfs_key_ptr[0] ptrs;
}

/*
 * btrfs_paths remember the path taken from the root down to the leaf.
 * level 0 is always the leaf, and nodes[1...BTRFS_MAX_LEVEL] will point
 * to any other levels that are present.
 *
 * The slots array records the index of the item or block pointer
 * used while walking the tree.
 */
enum { READA_NONE = 0, READA_BACK, READA_FORWARD }
struct btrfs_path {
	extent_buffer*[BTRFS_MAX_LEVEL] nodes;
	int[BTRFS_MAX_LEVEL] slots;
version (none) {
	/* The kernel locking scheme is not done in userspace. */
	int[BTRFS_MAX_LEVEL] locks;
}
	byte reada;
	/* keep some upper locks as we walk down */
	u8 lowest_level;

	/*
	 * set by btrfs_split_item, tells search_slot to keep all locks
	 * and to force calls to keep space in the nodes
	 */
	u8 search_for_split;
	u8 skip_check_block;
}

/*
 * items in the extent btree are used to record the objectid of the
 * owner of the block and the number of references
 */

struct btrfs_extent_item {
align(1):
	__le64 refs;
	__le64 generation;
	__le64 flags;
}

struct btrfs_extent_item_v0 {
align(1):
	__le32 refs;
}

auto BTRFS_MAX_EXTENT_ITEM_SIZE(T)(T r) { return
			((BTRFS_LEAF_DATA_SIZE(r.fs_info) >> 4) -
					btrfs_item.sizeof); }
enum BTRFS_MAX_EXTENT_SIZE		= SZ_128M;
enum BTRFS_EXTENT_FLAG_DATA		= (1UL << 0);
enum BTRFS_EXTENT_FLAG_TREE_BLOCK	= (1UL << 1);
/* following flags only apply to tree blocks */

/* use full backrefs for extent pointers in the block*/
enum BTRFS_BLOCK_FLAG_FULL_BACKREF	= (1UL << 8);
struct btrfs_tree_block_info {
align(1):
	btrfs_disk_key key;
	u8 level;
}

struct btrfs_extent_data_ref {
align(1):
	__le64 root;
	__le64 objectid;
	__le64 offset;
	__le32 count;
}

struct btrfs_shared_data_ref {
align(1):
	__le32 count;
}

struct btrfs_extent_inline_ref {
align(1):
	u8 type;
	__le64 offset;
}

struct btrfs_extent_ref_v0 {
align(1):
	__le64 root;
	__le64 generation;
	__le64 objectid;
	__le32 count;
}

/* dev extents record free space on individual devices.  The owner
 * field points back to the chunk allocation mapping tree that allocated
 * the extent.  The chunk tree uuid field is a way to double check the owner
 */
struct btrfs_dev_extent {
align(1):
	__le64 chunk_tree;
	__le64 chunk_objectid;
	__le64 chunk_offset;
	__le64 length;
	u8[BTRFS_UUID_SIZE] chunk_tree_uuid;
}

struct btrfs_inode_ref {
align(1):
	__le64 index;
	__le16 name_len;
	/* name goes here */
}

struct btrfs_inode_extref {
align(1):
	__le64 parent_objectid;
	__le64 index;
	__le16 name_len;
	__u8[0]   name; /* name goes here */
}

struct btrfs_timespec {
align(1):
	__le64 sec;
	__le32 nsec;
}

enum btrfs_compression_type {
	BTRFS_COMPRESS_NONE  = 0,
	BTRFS_COMPRESS_ZLIB  = 1,
	BTRFS_COMPRESS_LZO   = 2,
	BTRFS_COMPRESS_ZSTD  = 3,
	BTRFS_COMPRESS_TYPES = 3,
	BTRFS_COMPRESS_LAST  = 4,
}

/* we don't understand any encryption methods right now */
enum btrfs_encryption_type {
	BTRFS_ENCRYPTION_NONE = 0,
	BTRFS_ENCRYPTION_LAST = 1,
}

enum btrfs_tree_block_status {
	BTRFS_TREE_BLOCK_CLEAN,
	BTRFS_TREE_BLOCK_INVALID_NRITEMS,
	BTRFS_TREE_BLOCK_INVALID_PARENT_KEY,
	BTRFS_TREE_BLOCK_BAD_KEY_ORDER,
	BTRFS_TREE_BLOCK_INVALID_LEVEL,
	BTRFS_TREE_BLOCK_INVALID_FREE_SPACE,
	BTRFS_TREE_BLOCK_INVALID_OFFSETS,
}

struct btrfs_inode_item {
align(1):
	/* nfs style generation number */
	__le64 generation;
	/* transid that last touched this inode */
	__le64 transid;
	__le64 size;
	__le64 nbytes;
	__le64 block_group;
	__le32 nlink;
	__le32 uid;
	__le32 gid;
	__le32 mode;
	__le64 rdev;
	__le64 flags;

	/* modification sequence number for NFS */
	__le64 sequence;

	/*
	 * a little future expansion, for more than this we can
	 * just grow the inode item and version it
	 */
	__le64[4] reserved;
	btrfs_timespec atime;
	btrfs_timespec ctime;
	btrfs_timespec mtime;
	btrfs_timespec otime;
}

struct btrfs_dir_log_item {
align(1):
	__le64 end;
}

struct btrfs_dir_item {
align(1):
	btrfs_disk_key location;
	__le64 transid;
	__le16 data_len;
	__le16 name_len;
	u8 type;
}

struct btrfs_root_item_v0 {
align(1):
	btrfs_inode_item inode;
	__le64 generation;
	__le64 root_dirid;
	__le64 bytenr;
	__le64 byte_limit;
	__le64 bytes_used;
	__le64 last_snapshot;
	__le64 flags;
	__le32 refs;
	btrfs_disk_key drop_progress;
	u8 drop_level;
	u8 level;
}

struct btrfs_root_item {
align(1):
	btrfs_inode_item inode;
	__le64 generation;
	__le64 root_dirid;
	__le64 bytenr;
	__le64 byte_limit;
	__le64 bytes_used;
	__le64 last_snapshot;
	__le64 flags;
	__le32 refs;
	btrfs_disk_key drop_progress;
	u8 drop_level;
	u8 level;

	/*
	 * The following fields appear after subvol_uuids+subvol_times
	 * were introduced.
	 */

	/*
	 * This generation number is used to test if the new fields are valid
	 * and up to date while reading the root item. Every time the root item
	 * is written out, the "generation" field is copied into this field. If
	 * anyone ever mounted the fs with an older kernel, we will have
	 * mismatching generation values here and thus must invalidate the
	 * new fields. See btrfs_update_root and btrfs_find_last_root for
	 * details.
	 * the offset of generation_v2 is also used as the start for the memset
	 * when invalidating the fields.
	 */
	__le64 generation_v2;
	u8[BTRFS_UUID_SIZE] uuid;
	u8[BTRFS_UUID_SIZE] parent_uuid;
	u8[BTRFS_UUID_SIZE] received_uuid;
	__le64 ctransid; /* updated when an inode changes */
	__le64 otransid; /* trans when created */
	__le64 stransid; /* trans when sent. non-zero for received subvol */
	__le64 rtransid; /* trans when received. non-zero for received subvol */
	btrfs_timespec ctime;
	btrfs_timespec otime;
	btrfs_timespec stime;
	btrfs_timespec rtime;
        __le64[8] reserved; /* for future */
}

/*
 * this is used for both forward and backward root refs
 */
struct btrfs_root_ref {
align(1):
	__le64 dirid;
	__le64 sequence;
	__le16 name_len;
}

struct btrfs_disk_balance_args {
align(1):
	/*
	 * profiles to operate on, single is denoted by
	 * BTRFS_AVAIL_ALLOC_BIT_SINGLE
	 */
	__le64 profiles;

	/*
	 * usage filter
	 * BTRFS_BALANCE_ARGS_USAGE with a single value means '0..N'
	 * BTRFS_BALANCE_ARGS_USAGE_RANGE - range syntax, min..max
	 */
	union {
		__le64 usage;
		struct {
			__le32 usage_min;
			__le32 usage_max;
		}
	}

	/* devid filter */
	__le64 devid;

	/* devid subset filter [pstart..pend) */
	__le64 pstart;
	__le64 pend;

	/* btrfs virtual address space subset filter [vstart..vend) */
	__le64 vstart;
	__le64 vend;

	/*
	 * profile to convert to, single is denoted by
	 * BTRFS_AVAIL_ALLOC_BIT_SINGLE
	 */
	__le64 target;

	/* BTRFS_BALANCE_ARGS_* */
	__le64 flags;

	/*
	 * BTRFS_BALANCE_ARGS_LIMIT with value 'limit'
	 * BTRFS_BALANCE_ARGS_LIMIT_RANGE - the extend version can use minimum
	 * and maximum
	 */
	union {
		__le64 limit;
		struct {
			__le32 limit_min;
			__le32 limit_max;
		}
	}

	/*
	 * Process chunks that cross stripes_min..stripes_max devices,
	 * BTRFS_BALANCE_ARGS_STRIPES_RANGE
	 */
	__le32 stripes_min;
	__le32 stripes_max;

	__le64[6] unused;
}

/*
 * store balance parameters to disk so that balance can be properly
 * resumed after crash or unmount
 */
struct btrfs_balance_item {
align(1):
	/* BTRFS_BALANCE_* */
	__le64 flags;

	btrfs_disk_balance_args data;
	btrfs_disk_balance_args meta;
	btrfs_disk_balance_args sys;

	__le64[4] unused;
}

enum BTRFS_FILE_EXTENT_INLINE = 0;
enum BTRFS_FILE_EXTENT_REG = 1;
enum BTRFS_FILE_EXTENT_PREALLOC = 2;
struct btrfs_file_extent_item {
align(1):
	/*
	 * transaction id that created this extent
	 */
	__le64 generation;
	/*
	 * max number of bytes to hold this extent in ram
	 * when we split a compressed extent we can't know how big
	 * each of the resulting pieces will be.  So, this is
	 * an upper limit on the size of the extent in ram instead of
	 * an exact limit.
	 */
	__le64 ram_bytes;

	/*
	 * 32 bits for the various ways we might encode the data,
	 * including compression and encryption.  If any of these
	 * are set to something a given disk format doesn't understand
	 * it is treated like an incompat flag for reading and writing,
	 * but not for stat.
	 */
	u8 compression;
	u8 encryption;
	__le16 other_encoding; /* spare for later use */

	/* are we inline data or a real extent? */
	u8 type;

	/*
	 * Disk space consumed by the data extent
	 * Data checksum is stored in csum tree, thus no bytenr/length takes
	 * csum into consideration.
	 *
	 * The inline extent data starts at this offset in the structure.
	 */
	__le64 disk_bytenr;
	__le64 disk_num_bytes;
	/*
	 * The logical offset in file blocks.
	 * this extent record is for.  This allows a file extent to point
	 * into the middle of an existing extent on disk, sharing it
	 * between two snapshots (useful if some bytes in the middle of the
	 * extent have changed
	 */
	__le64 offset;
	/*
	 * The logical number of file blocks. This always reflects the size
	 * uncompressed and without encoding.
	 */
	__le64 num_bytes;

}

struct btrfs_dev_stats_item {
align(1):
        /*
         * grow this item struct at the end for future enhancements and keep
         * the existing values unchanged
         */
        __le64[btrfs_dev_stat_values.BTRFS_DEV_STAT_VALUES_MAX] values;
}

struct btrfs_csum_item {
align(1):
	u8 csum;
}

/*
 * We don't want to overwrite 1M at the beginning of device, even though
 * there is our 1st superblock at 64k. Some possible reasons:
 *  - the first 64k blank is useful for some boot loader/manager
 *  - the first 1M could be scratched by buggy partitioner or somesuch
 */
enum BTRFS_BLOCK_RESERVED_1M_FOR_SUPER	= (cast(u64)SZ_1M);
/* tag for the radix tree of block groups in ram */
enum BTRFS_BLOCK_GROUP_DATA		= (1UL << 0);
enum BTRFS_BLOCK_GROUP_SYSTEM	= (1UL << 1);
enum BTRFS_BLOCK_GROUP_METADATA	= (1UL << 2);
enum BTRFS_BLOCK_GROUP_RAID0		= (1UL << 3);
enum BTRFS_BLOCK_GROUP_RAID1		= (1UL << 4);
enum BTRFS_BLOCK_GROUP_DUP		= (1UL << 5);
enum BTRFS_BLOCK_GROUP_RAID10	= (1UL << 6);
enum BTRFS_BLOCK_GROUP_RAID5    	= (1UL << 7);
enum BTRFS_BLOCK_GROUP_RAID6    	= (1UL << 8);
enum BTRFS_BLOCK_GROUP_RAID1C3    	= (1UL << 9);
enum BTRFS_BLOCK_GROUP_RAID1C4    	= (1UL << 10);
enum BTRFS_BLOCK_GROUP_RESERVED	= BTRFS_AVAIL_ALLOC_BIT_SINGLE;
enum btrfs_raid_types {
	BTRFS_RAID_RAID10,
	BTRFS_RAID_RAID1,
	BTRFS_RAID_DUP,
	BTRFS_RAID_RAID0,
	BTRFS_RAID_SINGLE,
	BTRFS_RAID_RAID5,
	BTRFS_RAID_RAID6,
	BTRFS_RAID_RAID1C3,
	BTRFS_RAID_RAID1C4,
	BTRFS_NR_RAID_TYPES
}

enum BTRFS_BLOCK_GROUP_TYPE_MASK	= (BTRFS_BLOCK_GROUP_DATA |
					 BTRFS_BLOCK_GROUP_SYSTEM |
					 BTRFS_BLOCK_GROUP_METADATA);
enum BTRFS_BLOCK_GROUP_PROFILE_MASK	= (BTRFS_BLOCK_GROUP_RAID0 |
					 BTRFS_BLOCK_GROUP_RAID1 |
					 BTRFS_BLOCK_GROUP_RAID5 |
					 BTRFS_BLOCK_GROUP_RAID6 |
					 BTRFS_BLOCK_GROUP_RAID1C3 |
					 BTRFS_BLOCK_GROUP_RAID1C4 |
					 BTRFS_BLOCK_GROUP_DUP |
					 BTRFS_BLOCK_GROUP_RAID10);
/* used in struct btrfs_balance_args fields */
enum BTRFS_AVAIL_ALLOC_BIT_SINGLE	= (1UL << 48);
enum BTRFS_EXTENDED_PROFILE_MASK	= (BTRFS_BLOCK_GROUP_PROFILE_MASK |
					 BTRFS_AVAIL_ALLOC_BIT_SINGLE);
/*
 * GLOBAL_RSV does not exist as a on-disk block group type and is used
 * internally for exporting info about global block reserve from space infos
 */
enum BTRFS_SPACE_INFO_GLOBAL_RSV    = (1UL << 49);
enum BTRFS_QGROUP_LEVEL_SHIFT		= 48;
u64 btrfs_qgroup_level()(u64 qgroupid)
{
	return qgroupid >> BTRFS_QGROUP_LEVEL_SHIFT;
}

u64 btrfs_qgroup_subvid()(u64 qgroupid)
{
	return qgroupid & ((1UL << BTRFS_QGROUP_LEVEL_SHIFT) - 1);
}

enum BTRFS_QGROUP_STATUS_FLAG_ON		= (1UL << 0);
enum BTRFS_QGROUP_STATUS_FLAG_RESCAN		= (1UL << 1);
enum BTRFS_QGROUP_STATUS_FLAG_INCONSISTENT	= (1UL << 2);
struct btrfs_qgroup_status_item {
align(1):
	__le64 version_;
	__le64 generation;
	__le64 flags;
	__le64 rescan;		/* progress during scanning */
}

enum BTRFS_QGROUP_STATUS_VERSION		= 1;
struct btrfs_block_group_item {
align(1):
	__le64 used;
	__le64 chunk_objectid;
	__le64 flags;
}

struct btrfs_free_space_info {
align(1):
	__le32 extent_count;
	__le32 flags;
}

enum BTRFS_FREE_SPACE_USING_BITMAPS = (1UL << 0);
struct btrfs_qgroup_info_item {
align(1):
	__le64 generation;
	__le64 referenced;
	__le64 referenced_compressed;
	__le64 exclusive;
	__le64 exclusive_compressed;
}

/* flags definition for qgroup limits */
enum BTRFS_QGROUP_LIMIT_MAX_RFER	= (1UL << 0);
enum BTRFS_QGROUP_LIMIT_MAX_EXCL	= (1UL << 1);
enum BTRFS_QGROUP_LIMIT_RSV_RFER	= (1UL << 2);
enum BTRFS_QGROUP_LIMIT_RSV_EXCL	= (1UL << 3);
enum BTRFS_QGROUP_LIMIT_RFER_CMPR	= (1UL << 4);
enum BTRFS_QGROUP_LIMIT_EXCL_CMPR	= (1UL << 5);
struct btrfs_qgroup_limit_item {
align(1):
	__le64 flags;
	__le64 max_referenced;
	__le64 max_exclusive;
	__le64 rsv_referenced;
	__le64 rsv_exclusive;
}

struct btrfs_space_info {
	u64 flags;
	u64 total_bytes;
	/*
	 * Space already used.
	 * Only accounting space in current extent tree, thus delayed ref
	 * won't be accounted here.
	 */
	u64 bytes_used;

	/*
	 * Space being pinned down.
	 * So extent allocator will not try to allocate space from them.
	 *
	 * For cases like extents being freed in current transaction, or
	 * manually pinned bytes for re-initializing certain trees.
	 */
	u64 bytes_pinned;

	/*
	 * Space being reserved.
	 * Space has already being reserved but not yet reach extent tree.
	 *
	 * New tree blocks allocated in current transaction goes here.
	 */
	u64 bytes_reserved;
	int full;
	list_head list;
}

struct btrfs_block_group {
	btrfs_space_info *space_info;
	btrfs_free_space_ctl *free_space_ctl;
	u64 start;
	u64 length;
	u64 used;
	u64 bytes_super;
	u64 pinned;
	u64 flags;
	int cached;
	int ro;
	/*
	 * If the free space extent count exceeds this number, convert the block
	 * group to bitmaps.
	 */
	u32 bitmap_high_thresh;
	/*
	 * If the free space extent count drops below this number, convert the
	 * block group back to extents.
	 */
	u32 bitmap_low_thresh;

	/* Block group cache stuff */
	rb_node cache_node;

	/* For dirty block groups */
	list_head dirty_list;
}

struct btrfs_device;
struct btrfs_fs_devices;
struct btrfs_fs_info {
	u8[BTRFS_UUID_SIZE] chunk_tree_uuid;
	u8 *new_chunk_tree_uuid;
	btrfs_root *fs_root;
	btrfs_root *extent_root;
	btrfs_root *tree_root;
	btrfs_root *chunk_root;
	btrfs_root *dev_root;
	btrfs_root *csum_root;
	btrfs_root *quota_root;
	btrfs_root *free_space_root;
	btrfs_root *uuid_root;

	rb_root fs_root_tree;

	/* the log root tree is a directory of all the other log roots */
	btrfs_root *log_root_tree;

	extent_io_tree extent_cache;
	extent_io_tree free_space_cache;
	extent_io_tree pinned_extents;
	extent_io_tree extent_ins;
	extent_io_tree *excluded_extents;

	rb_root block_group_cache_tree;
	/* logical->physical extent mapping */
	btrfs_mapping_tree mapping_tree;

	u64 generation;
	u64 last_trans_committed;

	u64 avail_data_alloc_bits;
	u64 avail_metadata_alloc_bits;
	u64 avail_system_alloc_bits;
	u64 data_alloc_profile;
	u64 metadata_alloc_profile;
	u64 system_alloc_profile;

	btrfs_trans_handle *running_transaction;
	btrfs_super_block *super_copy;

	u64 super_bytenr;
	u64 total_pinned;

	list_head dirty_cowonly_roots;
	list_head recow_ebs;

	btrfs_fs_devices *fs_devices;
	list_head space_info;

	mixin(bitfields!(
		uint, q{system_allocs}, 1,
		uint, q{readonly}, 1,
		uint, q{on_restoring}, 1,
		uint, q{is_chunk_recover}, 1,
		uint, q{quota_enabled}, 1,
		uint, q{suppress_check_block_errors}, 1,
		uint, q{ignore_fsid_mismatch}, 1,
		uint, q{ignore_chunk_tree_error}, 1,
		uint, q{avoid_meta_chunk_alloc}, 1,
		uint, q{avoid_sys_chunk_alloc}, 1,
		uint, q{finalize_on_close}, 1,
		uint, q{hide_names}, 1,
		uint, q{}, 4,
	));

	int transaction_aborted;

	int function(u64 bytenr, u64 num_bytes, u64 parent,
				u64 root_objectid, u64 owner, u64 offset,
				int refs_to_drop) free_extent_hook;
	cache_tree *fsck_extent_cache;
	cache_tree *corrupt_blocks;

	/* Cached block sizes */
	u32 nodesize;
	u32 sectorsize;
	u32 stripesize;
}

/*
 * in ram representation of the tree.  extent_root is used for all allocations
 * and for the extent tree extent_root root.
 */
struct btrfs_root {
	extent_buffer *node;
	extent_buffer *commit_root;
	btrfs_root_item root_item;
	btrfs_key root_key;
	btrfs_fs_info *fs_info;
	u64 objectid;
	u64 last_trans;

	int ref_cows;
	int track_dirty;


	u32 type;
	u64 last_inode_alloc;

	list_head unaligned_extent_recs;

	/* the dirty list is only used by non-reference counted roots */
	list_head dirty_list;
	.rb_node rb_node;
}

u32 BTRFS_MAX_ITEM_SIZE()(const btrfs_fs_info *info)
{
	return BTRFS_LEAF_DATA_SIZE(info) - btrfs_item.sizeof;
}

u32 BTRFS_NODEPTRS_PER_BLOCK()(const btrfs_fs_info *info)
{
	return BTRFS_LEAF_DATA_SIZE(info) / btrfs_key_ptr.sizeof;
}

u32 BTRFS_NODEPTRS_PER_EXTENT_BUFFER(const extent_buffer *eb)
{
	assert(!(eb.fs_info && eb.fs_info.nodesize != eb.len));
	return cast(u32)(__BTRFS_LEAF_DATA_SIZE(eb.len) / btrfs_key_ptr.sizeof);
}

enum BTRFS_FILE_EXTENT_INLINE_DATA_START		=
	btrfs_file_extent_item.disk_bytenr.offsetof;
u32 BTRFS_MAX_INLINE_DATA_SIZE()(const btrfs_fs_info *info)
{
	return BTRFS_MAX_ITEM_SIZE(info) -
		BTRFS_FILE_EXTENT_INLINE_DATA_START;
}

u32 BTRFS_MAX_XATTR_SIZE()(const btrfs_fs_info *info)
{
	return BTRFS_MAX_ITEM_SIZE(info) - btrfs_dir_item.sizeof;
}

/*
 * inode items have the data typically returned from stat and store other
 * info about object characteristics.  There is one for every file and dir in
 * the FS
 */
enum BTRFS_INODE_ITEM_KEY		= 1;
enum BTRFS_INODE_REF_KEY		= 12;
enum BTRFS_INODE_EXTREF_KEY		= 13;
enum BTRFS_XATTR_ITEM_KEY		= 24;
enum BTRFS_ORPHAN_ITEM_KEY		= 48;
enum BTRFS_DIR_LOG_ITEM_KEY  = 60;
enum BTRFS_DIR_LOG_INDEX_KEY = 72;
/*
 * dir items are the name . inode pointers in a directory.  There is one
 * for every name in a directory.
 */
enum BTRFS_DIR_ITEM_KEY	= 84;
enum BTRFS_DIR_INDEX_KEY	= 96;
/*
 * extent data is for file data
 */
enum BTRFS_EXTENT_DATA_KEY	= 108;
/*
 * csum items have the checksums for data in the extents
 */
enum BTRFS_CSUM_ITEM_KEY	= 120;
/*
 * extent csums are stored in a separate tree and hold csums for
 * an entire extent on disk.
 */
enum BTRFS_EXTENT_CSUM_KEY	= 128;
/*
 * root items point to tree roots.  There are typically in the root
 * tree used by the super block to find all the other trees
 */
enum BTRFS_ROOT_ITEM_KEY	= 132;
/*
 * root backrefs tie subvols and snapshots to the directory entries that
 * reference them
 */
enum BTRFS_ROOT_BACKREF_KEY	= 144;
/*
 * root refs make a fast index for listing all of the snapshots and
 * subvolumes referenced by a given root.  They point directly to the
 * directory item in the root that references the subvol
 */
enum BTRFS_ROOT_REF_KEY	= 156;
/*
 * extent items are in the extent map tree.  These record which blocks
 * are used, and how many references there are to each block
 */
enum BTRFS_EXTENT_ITEM_KEY	= 168;
/*
 * The same as the BTRFS_EXTENT_ITEM_KEY, except it's metadata we already know
 * the length, so we save the level in key.offset instead of the length.
 */
enum BTRFS_METADATA_ITEM_KEY	= 169;
enum BTRFS_TREE_BLOCK_REF_KEY	= 176;
enum BTRFS_EXTENT_DATA_REF_KEY	= 178;
/* old style extent backrefs */
enum BTRFS_EXTENT_REF_V0_KEY		= 180;
enum BTRFS_SHARED_BLOCK_REF_KEY	= 182;
enum BTRFS_SHARED_DATA_REF_KEY	= 184;

/*
 * block groups give us hints into the extent allocation trees.  Which
 * blocks are free etc etc
 */
enum BTRFS_BLOCK_GROUP_ITEM_KEY = 192;
/*
 * Every block group is represented in the free space tree by a free space info
 * item, which stores some accounting information. It is keyed on
 * (block_group_start, FREE_SPACE_INFO, block_group_length).
 */
enum BTRFS_FREE_SPACE_INFO_KEY = 198;
/*
 * A free space extent tracks an extent of space that is free in a block group.
 * It is keyed on (start, FREE_SPACE_EXTENT, length).
 */
enum BTRFS_FREE_SPACE_EXTENT_KEY = 199;
/*
 * When a block group becomes very fragmented, we convert it to use bitmaps
 * instead of extents. A free space bitmap is keyed on
 * (start, FREE_SPACE_BITMAP, length); the corresponding item is a bitmap with
 * (length / sectorsize) bits.
 */
enum BTRFS_FREE_SPACE_BITMAP_KEY = 200;
enum BTRFS_DEV_EXTENT_KEY	= 204;
enum BTRFS_DEV_ITEM_KEY	= 216;
enum BTRFS_CHUNK_ITEM_KEY	= 228;
enum BTRFS_BALANCE_ITEM_KEY	= 248;
/*
 * quota groups
 */
enum BTRFS_QGROUP_STATUS_KEY		= 240;
enum BTRFS_QGROUP_INFO_KEY		= 242;
enum BTRFS_QGROUP_LIMIT_KEY		= 244;
enum BTRFS_QGROUP_RELATION_KEY	= 246;
/*
 * Obsolete name, see BTRFS_TEMPORARY_ITEM_KEY.
 */
//enum BTRFS_BALANCE_ITEM_KEY	= 248;
/*
 * The key type for tree items that are stored persistently, but do not need to
 * exist for extended period of time. The items can exist in any tree.
 *
 * [subtype, BTRFS_TEMPORARY_ITEM_KEY, data]
 *
 * Existing items:
 *
 * - balance status item
 *   (BTRFS_BALANCE_OBJECTID, BTRFS_TEMPORARY_ITEM_KEY, 0)
 */
enum BTRFS_TEMPORARY_ITEM_KEY	= 248;
/*
 * Obsolete name, see BTRFS_PERSISTENT_ITEM_KEY
 */
enum BTRFS_DEV_STATS_KEY		= 249;
/*
 * The key type for tree items that are stored persistently and usually exist
 * for a long period, eg. filesystem lifetime. The item kinds can be status
 * information, stats or preference values. The item can exist in any tree.
 *
 * [subtype, BTRFS_PERSISTENT_ITEM_KEY, data]
 *
 * Existing items:
 *
 * - device statistics, store IO stats in the device tree, one key for all
 *   stats
 *   (BTRFS_DEV_STATS_OBJECTID, BTRFS_DEV_STATS_KEY, 0)
 */
enum BTRFS_PERSISTENT_ITEM_KEY	= 249;
/*
 * Persistently stores the device replace state in the device tree.
 * The key is built like this: (0, BTRFS_DEV_REPLACE_KEY, 0).
 */
enum BTRFS_DEV_REPLACE_KEY	= 250;
/*
 * Stores items that allow to quickly map UUIDs to something else.
 * These items are part of the filesystem UUID tree.
 * The key is built like this:
 * (UUID_upper_64_bits, BTRFS_UUID_KEY*, UUID_lower_64_bits).
 */
static if (BTRFS_UUID_SIZE != 16) {
static assert(false, "UUID items require BTRFS_UUID_SIZE == 16!");
}
enum BTRFS_UUID_KEY_SUBVOL	= 251	/* for UUIDs assigned to subvols */;
enum BTRFS_UUID_KEY_RECEIVED_SUBVOL	= 252;	/* for UUIDs assigned to
						 * received subvols */

/*
 * string items are for debugging.  They just store a short string of
 * data in the FS
 */
enum BTRFS_STRING_ITEM_KEY	= 253;
/*
 * Inode flags
 */
enum BTRFS_INODE_NODATASUM		= (1 << 0);
enum BTRFS_INODE_NODATACOW		= (1 << 1);
enum BTRFS_INODE_READONLY		= (1 << 2);
enum BTRFS_INODE_NOCOMPRESS		= (1 << 3);
enum BTRFS_INODE_PREALLOC		= (1 << 4);
enum BTRFS_INODE_SYNC		= (1 << 5);
enum BTRFS_INODE_IMMUTABLE		= (1 << 6);
enum BTRFS_INODE_APPEND		= (1 << 7);
enum BTRFS_INODE_NODUMP		= (1 << 8);
enum BTRFS_INODE_NOATIME		= (1 << 9);
enum BTRFS_INODE_DIRSYNC		= (1 << 10);
enum BTRFS_INODE_COMPRESS		= (1 << 11);
void read_eb_member(
	type,
	string member,
)(
	const extent_buffer* eb,
	const void* ptr,
	void* result,
)
{
	read_extent_buffer(eb, cast(ubyte*)result,
			   (cast(ulong)(ptr)) +
			    mixin(q{type.} ~ member ~ q{.offsetof}),
               mixin(q{type.} ~ member ~ q{.sizeof}));
}

void write_eb_member(
	type,
	string member,
)(
	extent_buffer* eb,
	const void* ptr,
	void* result,
)
{
	write_extent_buffer(eb, cast(ubyte*)result,
			   (cast(ulong)(ptr)) +
			    mixin(q{type.} ~ member ~ q{.offsetof}),
               mixin(q{type.} ~ member ~ q{.sizeof}));
}

mixin template BTRFS_SETGET_HEADER_FUNCS(string name, type, string member, string bits)
{
	mixin(`
		u` ~ bits ~ ` btrfs_` ~ name ~ `()(const extent_buffer* eb)
		{
			const btrfs_header* h = cast(btrfs_header*)eb.data;
			return le` ~ bits ~ `_to_cpu(h.` ~ member ~ `);
		}
		void btrfs_set_` ~ name ~ `()(extent_buffer* eb,
							u` ~ bits ~ ` val)
		{
			btrfs_header *h = cast(btrfs_header*)eb.data;
			h.` ~ member ~ ` = cpu_to_le` ~ bits ~ `(val);
		}
	`);
}

mixin template BTRFS_SETGET_FUNCS(string name, type, string member, string bits)
{
	mixin(`
		u` ~ bits ~ ` btrfs_` ~ name ~ `()(const extent_buffer* eb,
						const type *s)
		{
			ulong offset = cast(ulong)s;
			const type* p = cast(type*) (eb.data.ptr + offset);
			return get_unaligned_le` ~ bits ~ `(&p.` ~ member ~ `);
		}
		void btrfs_set_` ~ name ~ `()(extent_buffer* eb,
						type *s, u` ~ bits ~ ` val)
		{
			ulong offset = cast(ulong)s;
			type* p = cast(type*) (eb.data.ptr + offset);
			put_unaligned_le` ~ bits ~ `(val, &p.` ~ member ~ `);
		}
	`);
}

mixin template BTRFS_SETGET_STACK_FUNCS(string name, type, string member, string bits)
{
	mixin(`
		u` ~ bits ~ ` btrfs_` ~ name ~ `()(const type* s)
		{
			return le` ~ bits ~ `_to_cpu(s.` ~ member ~ `);
		}
		void btrfs_set_` ~ name ~ `()(type* s, u` ~ bits ~ ` val)
		{
			s.member = cpu_to_le` ~ bits ~ `(val);
		}
	`);
}

mixin BTRFS_SETGET_FUNCS!(q{device_type}, btrfs_dev_item, q{type}, q{64});
mixin BTRFS_SETGET_FUNCS!(q{device_total_bytes}, btrfs_dev_item, q{total_bytes}, q{64});
mixin BTRFS_SETGET_FUNCS!(q{device_bytes_used}, btrfs_dev_item, q{bytes_used}, q{64});
mixin BTRFS_SETGET_FUNCS!(q{device_io_align}, btrfs_dev_item, q{io_align}, q{32});
mixin BTRFS_SETGET_FUNCS!(q{device_io_width}, btrfs_dev_item, q{io_width}, q{32});
mixin BTRFS_SETGET_FUNCS!(q{device_start_offset}, btrfs_dev_item,
		   q{start_offset}, q{64});
mixin BTRFS_SETGET_FUNCS!(q{device_sector_size}, btrfs_dev_item, q{sector_size}, q{32});
mixin BTRFS_SETGET_FUNCS!(q{device_id}, btrfs_dev_item, q{devid}, q{64});
mixin BTRFS_SETGET_FUNCS!(q{device_group}, btrfs_dev_item, q{dev_group}, q{32});
mixin BTRFS_SETGET_FUNCS!(q{device_seek_speed}, btrfs_dev_item, q{seek_speed}, q{8});
mixin BTRFS_SETGET_FUNCS!(q{device_bandwidth}, btrfs_dev_item, q{bandwidth}, q{8});
mixin BTRFS_SETGET_FUNCS!(q{device_generation}, btrfs_dev_item, q{generation}, q{64});

mixin BTRFS_SETGET_STACK_FUNCS!(q{stack_device_type}, btrfs_dev_item, q{type}, q{64});
mixin BTRFS_SETGET_STACK_FUNCS!(q{stack_device_total_bytes}, btrfs_dev_item,
			 q{total_bytes}, q{64});
mixin BTRFS_SETGET_STACK_FUNCS!(q{stack_device_bytes_used}, btrfs_dev_item,
			 q{bytes_used}, q{64});
mixin BTRFS_SETGET_STACK_FUNCS!(q{stack_device_io_align}, btrfs_dev_item,
			 q{io_align}, q{32});
mixin BTRFS_SETGET_STACK_FUNCS!(q{stack_device_io_width}, btrfs_dev_item,
			 q{io_width}, q{32});
mixin BTRFS_SETGET_STACK_FUNCS!(q{stack_device_sector_size}, btrfs_dev_item,
			 q{sector_size}, q{32});
mixin BTRFS_SETGET_STACK_FUNCS!(q{stack_device_id}, btrfs_dev_item, q{devid}, q{64});
mixin BTRFS_SETGET_STACK_FUNCS!(q{stack_device_group}, btrfs_dev_item,
			 q{dev_group}, q{32});
mixin BTRFS_SETGET_STACK_FUNCS!(q{stack_device_seek_speed}, btrfs_dev_item,
			 q{seek_speed}, q{8});
mixin BTRFS_SETGET_STACK_FUNCS!(q{stack_device_bandwidth}, btrfs_dev_item,
			 q{bandwidth}, q{8});
mixin BTRFS_SETGET_STACK_FUNCS!(q{stack_device_generation}, btrfs_dev_item,
			 q{generation}, q{64});

char *btrfs_device_uuid()(btrfs_dev_item *d)
{
	return cast(char *)d + btrfs_dev_item.uuid.offsetof;
}

char *btrfs_device_fsid()(btrfs_dev_item *d)
{
	return cast(char *)d + btrfs_dev_item.fsid.offsetof;
}

mixin BTRFS_SETGET_FUNCS!(q{chunk_length}, btrfs_chunk, q{length}, q{64});
mixin BTRFS_SETGET_FUNCS!(q{chunk_owner}, btrfs_chunk, q{owner}, q{64});
mixin BTRFS_SETGET_FUNCS!(q{chunk_stripe_len}, btrfs_chunk, q{stripe_len}, q{64});
mixin BTRFS_SETGET_FUNCS!(q{chunk_io_align}, btrfs_chunk, q{io_align}, q{32});
mixin BTRFS_SETGET_FUNCS!(q{chunk_io_width}, btrfs_chunk, q{io_width}, q{32});
mixin BTRFS_SETGET_FUNCS!(q{chunk_sector_size}, btrfs_chunk, q{sector_size}, q{32});
mixin BTRFS_SETGET_FUNCS!(q{chunk_type}, btrfs_chunk, q{type}, q{64});
mixin BTRFS_SETGET_FUNCS!(q{chunk_num_stripes}, btrfs_chunk, q{num_stripes}, q{16});
mixin BTRFS_SETGET_FUNCS!(q{chunk_sub_stripes}, btrfs_chunk, q{sub_stripes}, q{16});
mixin BTRFS_SETGET_FUNCS!(q{stripe_devid}, btrfs_stripe, q{devid}, q{64});
mixin BTRFS_SETGET_FUNCS!(q{stripe_offset}, btrfs_stripe, q{offset}, q{64});

char *btrfs_stripe_dev_uuid()(btrfs_stripe *s)
{
	return cast(char *)s + btrfs_stripe.dev_uuid.offsetof;
}

mixin BTRFS_SETGET_STACK_FUNCS!(q{stack_chunk_length}, btrfs_chunk, q{length}, q{64});
mixin BTRFS_SETGET_STACK_FUNCS!(q{stack_chunk_owner}, btrfs_chunk, q{owner}, q{64});
mixin BTRFS_SETGET_STACK_FUNCS!(q{stack_chunk_stripe_len}, btrfs_chunk,
			 q{stripe_len}, q{64});
mixin BTRFS_SETGET_STACK_FUNCS!(q{stack_chunk_io_align}, btrfs_chunk,
			 q{io_align}, q{32});
mixin BTRFS_SETGET_STACK_FUNCS!(q{stack_chunk_io_width}, btrfs_chunk,
			 q{io_width}, q{32});
mixin BTRFS_SETGET_STACK_FUNCS!(q{stack_chunk_sector_size}, btrfs_chunk,
			 q{sector_size}, q{32});
mixin BTRFS_SETGET_STACK_FUNCS!(q{stack_chunk_type}, btrfs_chunk, q{type}, q{64});
mixin BTRFS_SETGET_STACK_FUNCS!(q{stack_chunk_num_stripes}, btrfs_chunk,
			 q{num_stripes}, q{16});
mixin BTRFS_SETGET_STACK_FUNCS!(q{stack_chunk_sub_stripes}, btrfs_chunk,
			 q{sub_stripes}, q{16});
mixin BTRFS_SETGET_STACK_FUNCS!(q{stack_stripe_devid}, btrfs_stripe, q{devid}, q{64});
mixin BTRFS_SETGET_STACK_FUNCS!(q{stack_stripe_offset}, btrfs_stripe, q{offset}, q{64});

btrfs_stripe *btrfs_stripe_nr()(btrfs_chunk *c,
						   int nr)
{
	ulong offset = cast(ulong)c;
	offset += btrfs_chunk.stripe.offsetof;
	offset += nr * btrfs_stripe.sizeof;
	return cast(btrfs_stripe*)offset;
}

char *btrfs_stripe_dev_uuid_nr()(btrfs_chunk *c, int nr)
{
	return btrfs_stripe_dev_uuid(btrfs_stripe_nr(c, nr));
}

u64 btrfs_stripe_offset_nr()(extent_buffer *eb,
					 btrfs_chunk *c, int nr)
{
	return btrfs_stripe_offset(eb, btrfs_stripe_nr(c, nr));
}

void btrfs_set_stripe_offset_nr()(extent_buffer *eb,
					     btrfs_chunk *c, int nr,
					     u64 val)
{
	btrfs_set_stripe_offset(eb, btrfs_stripe_nr(c, nr), val);
}

u64 btrfs_stripe_devid_nr()(extent_buffer *eb,
					 btrfs_chunk *c, int nr)
{
	return btrfs_stripe_devid(eb, btrfs_stripe_nr(c, nr));
}

void btrfs_set_stripe_devid_nr()(extent_buffer *eb,
					     btrfs_chunk *c, int nr,
					     u64 val)
{
	btrfs_set_stripe_devid(eb, btrfs_stripe_nr(c, nr), val);
}

/* struct btrfs_block_group_item */
mixin BTRFS_SETGET_STACK_FUNCS!(q{stack_block_group_used}, btrfs_block_group_item,
			 q{used}, q{64});
mixin BTRFS_SETGET_FUNCS!(q{block_group_used}, btrfs_block_group_item,
			 q{used}, q{64});
mixin BTRFS_SETGET_STACK_FUNCS!(q{stack_block_group_chunk_objectid},
			 btrfs_block_group_item, q{chunk_objectid}, q{64});

mixin BTRFS_SETGET_FUNCS!(q{block_group_chunk_objectid},
		   btrfs_block_group_item, q{chunk_objectid}, q{64});
mixin BTRFS_SETGET_FUNCS!(q{block_group_flags},
		   btrfs_block_group_item, q{flags}, q{64});
mixin BTRFS_SETGET_STACK_FUNCS!(q{stack_block_group_flags},
			btrfs_block_group_item, q{flags}, q{64});

/* struct btrfs_free_space_info */
mixin BTRFS_SETGET_FUNCS!(q{free_space_extent_count}, btrfs_free_space_info,
		   q{extent_count}, q{32});
mixin BTRFS_SETGET_FUNCS!(q{free_space_flags}, btrfs_free_space_info, q{flags}, q{32});

/* struct btrfs_inode_ref */
mixin BTRFS_SETGET_FUNCS!(q{inode_ref_name_len}, btrfs_inode_ref, q{name_len}, q{16});
mixin BTRFS_SETGET_STACK_FUNCS!(q{stack_inode_ref_name_len}, btrfs_inode_ref, q{name_len}, q{16});
mixin BTRFS_SETGET_FUNCS!(q{inode_ref_index}, btrfs_inode_ref, q{index}, q{64});

/* struct btrfs_inode_extref */
mixin BTRFS_SETGET_FUNCS!(q{inode_extref_parent}, btrfs_inode_extref,
		   q{parent_objectid}, q{64});
mixin BTRFS_SETGET_FUNCS!(q{inode_extref_name_len}, btrfs_inode_extref,
		   q{name_len}, q{16});
mixin BTRFS_SETGET_FUNCS!(q{inode_extref_index}, btrfs_inode_extref, q{index}, q{64});

/* struct btrfs_inode_item */
mixin BTRFS_SETGET_FUNCS!(q{inode_generation}, btrfs_inode_item, q{generation}, q{64});
mixin BTRFS_SETGET_FUNCS!(q{inode_sequence}, btrfs_inode_item, q{sequence}, q{64});
mixin BTRFS_SETGET_FUNCS!(q{inode_transid}, btrfs_inode_item, q{transid}, q{64});
mixin BTRFS_SETGET_FUNCS!(q{inode_size}, btrfs_inode_item, q{size}, q{64});
mixin BTRFS_SETGET_FUNCS!(q{inode_nbytes}, btrfs_inode_item, q{nbytes}, q{64});
mixin BTRFS_SETGET_FUNCS!(q{inode_block_group}, btrfs_inode_item, q{block_group}, q{64});
mixin BTRFS_SETGET_FUNCS!(q{inode_nlink}, btrfs_inode_item, q{nlink}, q{32});
mixin BTRFS_SETGET_FUNCS!(q{inode_uid}, btrfs_inode_item, q{uid}, q{32});
mixin BTRFS_SETGET_FUNCS!(q{inode_gid}, btrfs_inode_item, q{gid}, q{32});
mixin BTRFS_SETGET_FUNCS!(q{inode_mode}, btrfs_inode_item, q{mode}, q{32});
mixin BTRFS_SETGET_FUNCS!(q{inode_rdev}, btrfs_inode_item, q{rdev}, q{64});
mixin BTRFS_SETGET_FUNCS!(q{inode_flags}, btrfs_inode_item, q{flags}, q{64});

mixin BTRFS_SETGET_STACK_FUNCS!(q{stack_inode_generation},
			 btrfs_inode_item, q{generation}, q{64});
mixin BTRFS_SETGET_STACK_FUNCS!(q{stack_inode_sequence},
			 btrfs_inode_item, q{sequence}, q{64});
mixin BTRFS_SETGET_STACK_FUNCS!(q{stack_inode_transid},
			 btrfs_inode_item, q{transid}, q{64});
mixin BTRFS_SETGET_STACK_FUNCS!(q{stack_inode_size},
			 btrfs_inode_item, q{size}, q{64});
mixin BTRFS_SETGET_STACK_FUNCS!(q{stack_inode_nbytes},
			 btrfs_inode_item, q{nbytes}, q{64});
mixin BTRFS_SETGET_STACK_FUNCS!(q{stack_inode_block_group},
			 btrfs_inode_item, q{block_group}, q{64});
mixin BTRFS_SETGET_STACK_FUNCS!(q{stack_inode_nlink},
			 btrfs_inode_item, q{nlink}, q{32});
mixin BTRFS_SETGET_STACK_FUNCS!(q{stack_inode_uid},
			 btrfs_inode_item, q{uid}, q{32});
mixin BTRFS_SETGET_STACK_FUNCS!(q{stack_inode_gid},
			 btrfs_inode_item, q{gid}, q{32});
mixin BTRFS_SETGET_STACK_FUNCS!(q{stack_inode_mode},
			 btrfs_inode_item, q{mode}, q{32});
mixin BTRFS_SETGET_STACK_FUNCS!(q{stack_inode_rdev},
			 btrfs_inode_item, q{rdev}, q{64});
mixin BTRFS_SETGET_STACK_FUNCS!(q{stack_inode_flags},
			 btrfs_inode_item, q{flags}, q{64});

btrfs_timespec *
btrfs_inode_atime()(btrfs_inode_item *inode_item)
{
	ulong ptr = cast(ulong)inode_item;
	ptr += btrfs_inode_item.atime.offsetof;
	return cast(btrfs_timespec*)ptr;
}

btrfs_timespec *
btrfs_inode_mtime()(btrfs_inode_item *inode_item)
{
	ulong ptr = cast(ulong)inode_item;
	ptr += btrfs_inode_item.mtime.offsetof;
	return cast(btrfs_timespec*)ptr;
}

btrfs_timespec *
btrfs_inode_ctime()(btrfs_inode_item *inode_item)
{
	ulong ptr = cast(ulong)inode_item;
	ptr += btrfs_inode_item.ctime.offsetof;
	return cast(btrfs_timespec*)ptr;
}

btrfs_timespec *
btrfs_inode_otime()(btrfs_inode_item *inode_item)
{
	ulong ptr = cast(ulong)inode_item;
	ptr += btrfs_inode_item.otime.offsetof;
	return cast(btrfs_timespec*)ptr;
}

mixin BTRFS_SETGET_FUNCS!(q{timespec_sec}, btrfs_timespec, q{sec}, q{64});
mixin BTRFS_SETGET_FUNCS!(q{timespec_nsec}, btrfs_timespec, q{nsec}, q{32});
mixin BTRFS_SETGET_STACK_FUNCS!(q{stack_timespec_sec}, btrfs_timespec,
			 q{sec}, q{64});
mixin BTRFS_SETGET_STACK_FUNCS!(q{stack_timespec_nsec}, btrfs_timespec,
			 q{nsec}, q{32});

/* struct btrfs_dev_extent */
mixin BTRFS_SETGET_FUNCS!(q{dev_extent_chunk_tree}, btrfs_dev_extent,
		   q{chunk_tree}, q{64});
mixin BTRFS_SETGET_FUNCS!(q{dev_extent_chunk_objectid}, btrfs_dev_extent,
		   q{chunk_objectid}, q{64});
mixin BTRFS_SETGET_FUNCS!(q{dev_extent_chunk_offset}, btrfs_dev_extent,
		   q{chunk_offset}, q{64});
mixin BTRFS_SETGET_FUNCS!(q{dev_extent_length}, btrfs_dev_extent, q{length}, q{64});

mixin BTRFS_SETGET_STACK_FUNCS!(q{stack_dev_extent_length}, btrfs_dev_extent,
			 q{length}, q{64});

u8 *btrfs_dev_extent_chunk_tree_uuid()(btrfs_dev_extent *dev)
{
	ulong ptr = btrfs_dev_extent.chunk_tree_uuid.offsetof;
	return cast(u8*)(cast(ulong)dev + ptr);
}


/* struct btrfs_extent_item */
mixin BTRFS_SETGET_FUNCS!(q{extent_refs}, btrfs_extent_item, q{refs}, q{64});
mixin BTRFS_SETGET_STACK_FUNCS!(q{stack_extent_refs}, btrfs_extent_item, q{refs}, q{64});
mixin BTRFS_SETGET_FUNCS!(q{extent_generation}, btrfs_extent_item,
		   q{generation}, q{64});
mixin BTRFS_SETGET_FUNCS!(q{extent_flags}, btrfs_extent_item, q{flags}, q{64});
mixin BTRFS_SETGET_STACK_FUNCS!(q{stack_extent_flags}, btrfs_extent_item, q{flags}, q{64});

mixin BTRFS_SETGET_FUNCS!(q{extent_refs_v0}, btrfs_extent_item_v0, q{refs}, q{32});

mixin BTRFS_SETGET_FUNCS!(q{tree_block_level}, btrfs_tree_block_info, q{level}, q{8});

void btrfs_tree_block_key()(extent_buffer *eb,
					btrfs_tree_block_info *item,
					btrfs_disk_key *key)
{
	read_eb_member!(btrfs_tree_block_info, q{key})(eb, item, key);
}

void btrfs_set_tree_block_key()(extent_buffer *eb,
					    btrfs_tree_block_info *item,
					    btrfs_disk_key *key)
{
	write_eb_member!(btrfs_tree_block_info, q{key})(eb, item, key);
}

mixin BTRFS_SETGET_FUNCS!(q{extent_data_ref_root}, btrfs_extent_data_ref,
		   q{root}, q{64});
mixin BTRFS_SETGET_FUNCS!(q{extent_data_ref_objectid}, btrfs_extent_data_ref,
		   q{objectid}, q{64});
mixin BTRFS_SETGET_FUNCS!(q{extent_data_ref_offset}, btrfs_extent_data_ref,
		   q{offset}, q{64});
mixin BTRFS_SETGET_FUNCS!(q{extent_data_ref_count}, btrfs_extent_data_ref,
		   q{count}, q{32});

mixin BTRFS_SETGET_FUNCS!(q{shared_data_ref_count}, btrfs_shared_data_ref,
		   q{count}, q{32});

mixin BTRFS_SETGET_FUNCS!(q{extent_inline_ref_type}, btrfs_extent_inline_ref,
		   q{type}, q{8});
mixin BTRFS_SETGET_FUNCS!(q{extent_inline_ref_offset}, btrfs_extent_inline_ref,
		   q{offset}, q{64});
mixin BTRFS_SETGET_STACK_FUNCS!(q{stack_extent_inline_ref_type},
			 btrfs_extent_inline_ref, q{type}, q{8});
mixin BTRFS_SETGET_STACK_FUNCS!(q{stack_extent_inline_ref_offset},
			 btrfs_extent_inline_ref, q{offset}, q{64});

u32 btrfs_extent_inline_ref_size()(int type)
{
	if (type == BTRFS_TREE_BLOCK_REF_KEY ||
	    type == BTRFS_SHARED_BLOCK_REF_KEY)
		return btrfs_extent_inline_ref.sizeof;
	if (type == BTRFS_SHARED_DATA_REF_KEY)
		return btrfs_shared_data_ref.sizeof +
		       btrfs_extent_inline_ref.sizeof;
	if (type == BTRFS_EXTENT_DATA_REF_KEY)
		return btrfs_extent_data_ref.sizeof +
		       btrfs_extent_inline_ref.offset.offsetof;
	BUG();
	return 0;
}

mixin BTRFS_SETGET_FUNCS!(q{ref_root_v0}, btrfs_extent_ref_v0, q{root}, q{64});
mixin BTRFS_SETGET_FUNCS!(q{ref_generation_v0}, btrfs_extent_ref_v0,
		   q{generation}, q{64});
mixin BTRFS_SETGET_FUNCS!(q{ref_objectid_v0}, btrfs_extent_ref_v0, q{objectid}, q{64});
mixin BTRFS_SETGET_FUNCS!(q{ref_count_v0}, btrfs_extent_ref_v0, q{count}, q{32});

/* struct btrfs_node */
mixin BTRFS_SETGET_FUNCS!(q{key_blockptr}, btrfs_key_ptr, q{blockptr}, q{64});
mixin BTRFS_SETGET_FUNCS!(q{key_generation}, btrfs_key_ptr, q{generation}, q{64});

u64 btrfs_node_blockptr()(extent_buffer *eb, int nr)
{
	ulong ptr;
	ptr = btrfs_node.ptrs.offsetof +
		btrfs_key_ptr.sizeof * nr;
	return btrfs_key_blockptr(eb, cast(btrfs_key_ptr *)ptr);
}

void btrfs_set_node_blockptr()(extent_buffer *eb,
					   int nr, u64 val)
{
	ulong ptr;
	ptr = btrfs_node.ptrs.offsetof +
		btrfs_key_ptr.sizeof * nr;
	btrfs_set_key_blockptr(eb, cast(btrfs_key_ptr *)ptr, val);
}

u64 btrfs_node_ptr_generation()(extent_buffer *eb, int nr)
{
	ulong ptr;
	ptr = btrfs_node.ptrs.offsetof +
		btrfs_key_ptr.sizeof * nr;
	return btrfs_key_generation(eb, cast(btrfs_key_ptr *)ptr);
}

void btrfs_set_node_ptr_generation()(extent_buffer *eb,
						 int nr, u64 val)
{
	ulong ptr;
	ptr = btrfs_node.ptrs.offsetof +
		btrfs_key_ptr.sizeof * nr;
	btrfs_set_key_generation(eb, cast(btrfs_key_ptr *)ptr, val);
}

ulong btrfs_node_key_ptr_offset()(int nr)
{
	return btrfs_node.ptrs.offsetof +
		btrfs_key_ptr.sizeof * nr;
}

void btrfs_node_key()(extent_buffer *eb,
				  btrfs_disk_key *disk_key, int nr)
{
	ulong ptr;
	ptr = btrfs_node_key_ptr_offset(nr);
	read_eb_member!(
		       btrfs_key_ptr, q{key})(eb, cast(btrfs_key_ptr *)ptr, disk_key);
}

void btrfs_set_node_key()(extent_buffer *eb,
				      btrfs_disk_key *disk_key, int nr)
{
	ulong ptr;
	ptr = btrfs_node_key_ptr_offset(nr);
	write_eb_member!(
		       btrfs_key_ptr, q{key})(eb, cast(btrfs_key_ptr *)ptr, disk_key);
}

/* struct btrfs_item */
mixin BTRFS_SETGET_FUNCS!(q{item_offset}, btrfs_item, q{offset}, q{32});
mixin BTRFS_SETGET_FUNCS!(q{item_size}, btrfs_item, q{size}, q{32});

ulong btrfs_item_nr_offset()(int nr)
{
	return btrfs_leaf.items.offsetof +
		btrfs_item.sizeof * nr;
}

btrfs_item *btrfs_item_nr()(int nr)
{
	return cast(btrfs_item*)btrfs_item_nr_offset(nr);
}

u32 btrfs_item_end()(extent_buffer *eb,
				 btrfs_item *item)
{
	return btrfs_item_offset(eb, item) + btrfs_item_size(eb, item);
}

u32 btrfs_item_end_nr()(extent_buffer *eb, int nr)
{
	return btrfs_item_end(eb, btrfs_item_nr(nr));
}

u32 btrfs_item_offset_nr()(const extent_buffer *eb, int nr)
{
	return btrfs_item_offset(eb, btrfs_item_nr(nr));
}

u32 btrfs_item_size_nr()(extent_buffer *eb, int nr)
{
	return btrfs_item_size(eb, btrfs_item_nr(nr));
}

void btrfs_item_key()(extent_buffer *eb,
			   btrfs_disk_key *disk_key, int nr)
{
	btrfs_item *item = btrfs_item_nr(nr);
	read_eb_member!(btrfs_item, q{key})(eb, item, disk_key);
}

void btrfs_set_item_key()(extent_buffer *eb,
			       btrfs_disk_key *disk_key, int nr)
{
	btrfs_item *item = btrfs_item_nr(nr);
	write_eb_member!(btrfs_item, q{key})(eb, item, disk_key);
}

mixin BTRFS_SETGET_FUNCS!(q{dir_log_end}, btrfs_dir_log_item, q{end}, q{64});

/*
 * struct btrfs_root_ref
 */
mixin BTRFS_SETGET_FUNCS!(q{root_ref_dirid}, btrfs_root_ref, q{dirid}, q{64});
mixin BTRFS_SETGET_FUNCS!(q{root_ref_sequence}, btrfs_root_ref, q{sequence}, q{64});
mixin BTRFS_SETGET_FUNCS!(q{root_ref_name_len}, btrfs_root_ref, q{name_len}, q{16});

mixin BTRFS_SETGET_STACK_FUNCS!(q{stack_root_ref_dirid}, btrfs_root_ref, q{dirid}, q{64});
mixin BTRFS_SETGET_STACK_FUNCS!(q{stack_root_ref_sequence}, btrfs_root_ref, q{sequence}, q{64});
mixin BTRFS_SETGET_STACK_FUNCS!(q{stack_root_ref_name_len}, btrfs_root_ref, q{name_len}, q{16});

/* struct btrfs_dir_item */
mixin BTRFS_SETGET_FUNCS!(q{dir_data_len}, btrfs_dir_item, q{data_len}, q{16});
mixin BTRFS_SETGET_FUNCS!(q{dir_type}, btrfs_dir_item, q{type}, q{8});
mixin BTRFS_SETGET_FUNCS!(q{dir_name_len}, btrfs_dir_item, q{name_len}, q{16});
mixin BTRFS_SETGET_FUNCS!(q{dir_transid}, btrfs_dir_item, q{transid}, q{64});

mixin BTRFS_SETGET_STACK_FUNCS!(q{stack_dir_data_len}, btrfs_dir_item, q{data_len}, q{16});
mixin BTRFS_SETGET_STACK_FUNCS!(q{stack_dir_type}, btrfs_dir_item, q{type}, q{8});
mixin BTRFS_SETGET_STACK_FUNCS!(q{stack_dir_name_len}, btrfs_dir_item, q{name_len}, q{16});
mixin BTRFS_SETGET_STACK_FUNCS!(q{stack_dir_transid}, btrfs_dir_item, q{transid}, q{64});

void btrfs_dir_item_key()(extent_buffer *eb,
				      btrfs_dir_item *item,
				      btrfs_disk_key *key)
{
	read_eb_member!(btrfs_dir_item, q{location})(eb, item, key);
}

void btrfs_set_dir_item_key()(extent_buffer *eb,
					  btrfs_dir_item *item,
					  btrfs_disk_key *key)
{
	write_eb_member!(btrfs_dir_item, q{location})(eb, item, key);
}

/* struct btrfs_free_space_header */
mixin BTRFS_SETGET_FUNCS!(q{free_space_entries}, btrfs_free_space_header,
		   q{num_entries}, q{64});
mixin BTRFS_SETGET_FUNCS!(q{free_space_bitmaps}, btrfs_free_space_header,
		   q{num_bitmaps}, q{64});
mixin BTRFS_SETGET_FUNCS!(q{free_space_generation}, btrfs_free_space_header,
		   q{generation}, q{64});

void btrfs_free_space_key()(extent_buffer *eb,
					btrfs_free_space_header *h,
					btrfs_disk_key *key)
{
	read_eb_member!(btrfs_free_space_header, q{location})(eb, h, key);
}

void btrfs_set_free_space_key()(extent_buffer *eb,
					    btrfs_free_space_header *h,
					    btrfs_disk_key *key)
{
	write_eb_member!(btrfs_free_space_header, q{location})(eb, h, key);
}

/* struct btrfs_disk_key */
mixin BTRFS_SETGET_STACK_FUNCS!(q{disk_key_objectid}, btrfs_disk_key,
			 q{objectid}, q{64});
mixin BTRFS_SETGET_STACK_FUNCS!(q{disk_key_offset}, btrfs_disk_key, q{offset}, q{64});
mixin BTRFS_SETGET_STACK_FUNCS!(q{disk_key_type}, btrfs_disk_key, q{type}, q{8});

void btrfs_disk_key_to_cpu(btrfs_key *cpu,
					 btrfs_disk_key *disk)
{
	cpu.offset = le64_to_cpu(disk.offset);
	cpu.type = disk.type;
	cpu.objectid = le64_to_cpu(disk.objectid);
}

void btrfs_cpu_key_to_disk(btrfs_disk_key *disk,
					 const btrfs_key *cpu)
{
	disk.offset = cpu_to_le64(cpu.offset);
	disk.type = cpu.type;
	disk.objectid = cpu_to_le64(cpu.objectid);
}

void btrfs_node_key_to_cpu()(extent_buffer *eb,
				  btrfs_key *key, int nr)
{
	btrfs_disk_key disk_key;
	btrfs_node_key(eb, &disk_key, nr);
	btrfs_disk_key_to_cpu(key, &disk_key);
}

void btrfs_item_key_to_cpu()(extent_buffer *eb,
				  btrfs_key *key, int nr)
{
	btrfs_disk_key disk_key;
	btrfs_item_key(eb, &disk_key, nr);
	btrfs_disk_key_to_cpu(key, &disk_key);
}

void btrfs_dir_item_key_to_cpu()(extent_buffer *eb,
				      btrfs_dir_item *item,
				      btrfs_key *key)
{
	btrfs_disk_key disk_key;
	btrfs_dir_item_key(eb, item, &disk_key);
	btrfs_disk_key_to_cpu(key, &disk_key);
}

/* struct btrfs_header */
mixin BTRFS_SETGET_HEADER_FUNCS!(q{header_bytenr}, btrfs_header, q{bytenr}, q{64});
mixin BTRFS_SETGET_HEADER_FUNCS!(q{header_generation}, btrfs_header,
			  q{generation}, q{64});
mixin BTRFS_SETGET_HEADER_FUNCS!(q{header_owner}, btrfs_header, q{owner}, q{64});
mixin BTRFS_SETGET_HEADER_FUNCS!(q{header_nritems}, btrfs_header, q{nritems}, q{32});
mixin BTRFS_SETGET_HEADER_FUNCS!(q{header_flags}, btrfs_header, q{flags}, q{64});
mixin BTRFS_SETGET_HEADER_FUNCS!(q{header_level}, btrfs_header, q{level}, q{8});
mixin BTRFS_SETGET_STACK_FUNCS!(q{stack_header_bytenr}, btrfs_header, q{bytenr}, q{64});
mixin BTRFS_SETGET_STACK_FUNCS!(q{stack_header_nritems}, btrfs_header, q{nritems},
			 q{32});
mixin BTRFS_SETGET_STACK_FUNCS!(q{stack_header_owner}, btrfs_header, q{owner}, q{64});
mixin BTRFS_SETGET_STACK_FUNCS!(q{stack_header_generation}, btrfs_header,
			 q{generation}, q{64});

int btrfs_header_flag(extent_buffer *eb, u64 flag)
{
	return (btrfs_header_flags(eb) & flag) == flag;
}

int btrfs_set_header_flag(extent_buffer *eb, u64 flag)
{
	u64 flags = btrfs_header_flags(eb);
	btrfs_set_header_flags(eb, flags | flag);
	return (flags & flag) == flag;
}

int btrfs_clear_header_flag(extent_buffer *eb, u64 flag)
{
	u64 flags = btrfs_header_flags(eb);
	btrfs_set_header_flags(eb, flags & ~flag);
	return (flags & flag) == flag;
}

int btrfs_header_backref_rev(extent_buffer *eb)
{
	u64 flags = btrfs_header_flags(eb);
	return flags >> BTRFS_BACKREF_REV_SHIFT;
}

void btrfs_set_header_backref_rev()(extent_buffer *eb,
						int rev)
{
	u64 flags = btrfs_header_flags(eb);
	flags &= ~BTRFS_BACKREF_REV_MASK;
	flags |= cast(u64)rev << BTRFS_BACKREF_REV_SHIFT;
	btrfs_set_header_flags(eb, flags);
}

ulong btrfs_header_fsid()
{
	return btrfs_header.fsid.offsetof;
}

ulong btrfs_header_chunk_tree_uuid(extent_buffer *eb)
{
	return btrfs_header.chunk_tree_uuid.offsetof;
}

u8 *btrfs_header_csum(extent_buffer *eb)
{
	ulong ptr = btrfs_header.csum.offsetof;
	return cast(u8*)ptr;
}

int btrfs_is_leaf(extent_buffer *eb)
{
	return (btrfs_header_level(eb) == 0);
}

/* struct btrfs_root_item */
mixin BTRFS_SETGET_FUNCS!(q{disk_root_generation}, btrfs_root_item,
		   q{generation}, q{64});
mixin BTRFS_SETGET_FUNCS!(q{disk_root_refs}, btrfs_root_item, q{refs}, q{32});
mixin BTRFS_SETGET_FUNCS!(q{disk_root_bytenr}, btrfs_root_item, q{bytenr}, q{64});
mixin BTRFS_SETGET_FUNCS!(q{disk_root_level}, btrfs_root_item, q{level}, q{8});

mixin BTRFS_SETGET_STACK_FUNCS!(q{root_generation}, btrfs_root_item,
			 q{generation}, q{64});
mixin BTRFS_SETGET_STACK_FUNCS!(q{root_bytenr}, btrfs_root_item, q{bytenr}, q{64});
mixin BTRFS_SETGET_STACK_FUNCS!(q{root_level}, btrfs_root_item, q{level}, q{8});
mixin BTRFS_SETGET_STACK_FUNCS!(q{root_dirid}, btrfs_root_item, q{root_dirid}, q{64});
mixin BTRFS_SETGET_STACK_FUNCS!(q{root_refs}, btrfs_root_item, q{refs}, q{32});
mixin BTRFS_SETGET_STACK_FUNCS!(q{root_flags}, btrfs_root_item, q{flags}, q{64});
mixin BTRFS_SETGET_STACK_FUNCS!(q{root_used}, btrfs_root_item, q{bytes_used}, q{64});
mixin BTRFS_SETGET_STACK_FUNCS!(q{root_limit}, btrfs_root_item, q{byte_limit}, q{64});
mixin BTRFS_SETGET_STACK_FUNCS!(q{root_last_snapshot}, btrfs_root_item,
			 q{last_snapshot}, q{64});
mixin BTRFS_SETGET_STACK_FUNCS!(q{root_generation_v2}, btrfs_root_item,
			 q{generation_v2}, q{64});
mixin BTRFS_SETGET_STACK_FUNCS!(q{root_ctransid}, btrfs_root_item,
			 q{ctransid}, q{64});
mixin BTRFS_SETGET_STACK_FUNCS!(q{root_otransid}, btrfs_root_item,
			 q{otransid}, q{64});
mixin BTRFS_SETGET_STACK_FUNCS!(q{root_stransid}, btrfs_root_item,
			 q{stransid}, q{64});
mixin BTRFS_SETGET_STACK_FUNCS!(q{root_rtransid}, btrfs_root_item,
			 q{rtransid}, q{64});

btrfs_timespec* btrfs_root_ctime(
		btrfs_root_item *root_item)
{
	ulong ptr = cast(ulong)root_item;
	ptr += btrfs_root_item.ctime.offsetof;
	return cast(btrfs_timespec*)ptr;
}

btrfs_timespec* btrfs_root_otime(
		btrfs_root_item *root_item)
{
	ulong ptr = cast(ulong)root_item;
	ptr += btrfs_root_item.otime.offsetof;
	return cast(btrfs_timespec*)ptr;
}

btrfs_timespec* btrfs_root_stime(
		btrfs_root_item *root_item)
{
	ulong ptr = cast(ulong)root_item;
	ptr += btrfs_root_item.stime.offsetof;
	return cast(btrfs_timespec*)ptr;
}

btrfs_timespec* btrfs_root_rtime(
		btrfs_root_item *root_item)
{
	ulong ptr = cast(ulong)root_item;
	ptr += btrfs_root_item.rtime.offsetof;
	return cast(btrfs_timespec*)ptr;
}

/* struct btrfs_root_backup */
mixin BTRFS_SETGET_STACK_FUNCS!(q{backup_tree_root}, btrfs_root_backup,
		   q{tree_root}, q{64});
mixin BTRFS_SETGET_STACK_FUNCS!(q{backup_tree_root_gen}, btrfs_root_backup,
		   q{tree_root_gen}, q{64});
mixin BTRFS_SETGET_STACK_FUNCS!(q{backup_tree_root_level}, btrfs_root_backup,
		   q{tree_root_level}, q{8});

mixin BTRFS_SETGET_STACK_FUNCS!(q{backup_chunk_root}, btrfs_root_backup,
		   q{chunk_root}, q{64});
mixin BTRFS_SETGET_STACK_FUNCS!(q{backup_chunk_root_gen}, btrfs_root_backup,
		   q{chunk_root_gen}, q{64});
mixin BTRFS_SETGET_STACK_FUNCS!(q{backup_chunk_root_level}, btrfs_root_backup,
		   q{chunk_root_level}, q{8});

mixin BTRFS_SETGET_STACK_FUNCS!(q{backup_extent_root}, btrfs_root_backup,
		   q{extent_root}, q{64});
mixin BTRFS_SETGET_STACK_FUNCS!(q{backup_extent_root_gen}, btrfs_root_backup,
		   q{extent_root_gen}, q{64});
mixin BTRFS_SETGET_STACK_FUNCS!(q{backup_extent_root_level}, btrfs_root_backup,
		   q{extent_root_level}, q{8});

mixin BTRFS_SETGET_STACK_FUNCS!(q{backup_fs_root}, btrfs_root_backup,
		   q{fs_root}, q{64});
mixin BTRFS_SETGET_STACK_FUNCS!(q{backup_fs_root_gen}, btrfs_root_backup,
		   q{fs_root_gen}, q{64});
mixin BTRFS_SETGET_STACK_FUNCS!(q{backup_fs_root_level}, btrfs_root_backup,
		   q{fs_root_level}, q{8});

mixin BTRFS_SETGET_STACK_FUNCS!(q{backup_dev_root}, btrfs_root_backup,
		   q{dev_root}, q{64});
mixin BTRFS_SETGET_STACK_FUNCS!(q{backup_dev_root_gen}, btrfs_root_backup,
		   q{dev_root_gen}, q{64});
mixin BTRFS_SETGET_STACK_FUNCS!(q{backup_dev_root_level}, btrfs_root_backup,
		   q{dev_root_level}, q{8});

mixin BTRFS_SETGET_STACK_FUNCS!(q{backup_csum_root}, btrfs_root_backup,
		   q{csum_root}, q{64});
mixin BTRFS_SETGET_STACK_FUNCS!(q{backup_csum_root_gen}, btrfs_root_backup,
		   q{csum_root_gen}, q{64});
mixin BTRFS_SETGET_STACK_FUNCS!(q{backup_csum_root_level}, btrfs_root_backup,
		   q{csum_root_level}, q{8});
mixin BTRFS_SETGET_STACK_FUNCS!(q{backup_total_bytes}, btrfs_root_backup,
		   q{total_bytes}, q{64});
mixin BTRFS_SETGET_STACK_FUNCS!(q{backup_bytes_used}, btrfs_root_backup,
		   q{bytes_used}, q{64});
mixin BTRFS_SETGET_STACK_FUNCS!(q{backup_num_devices}, btrfs_root_backup,
		   q{num_devices}, q{64});

/* struct btrfs_super_block */

mixin BTRFS_SETGET_STACK_FUNCS!(q{super_bytenr}, btrfs_super_block, q{bytenr}, q{64});
mixin BTRFS_SETGET_STACK_FUNCS!(q{super_flags}, btrfs_super_block, q{flags}, q{64});
mixin BTRFS_SETGET_STACK_FUNCS!(q{super_generation}, btrfs_super_block,
			 q{generation}, q{64});
mixin BTRFS_SETGET_STACK_FUNCS!(q{super_root}, btrfs_super_block, q{root}, q{64});
mixin BTRFS_SETGET_STACK_FUNCS!(q{super_sys_array_size},
			 btrfs_super_block, q{sys_chunk_array_size}, q{32});
mixin BTRFS_SETGET_STACK_FUNCS!(q{super_chunk_root_generation},
			 btrfs_super_block, q{chunk_root_generation}, q{64});
mixin BTRFS_SETGET_STACK_FUNCS!(q{super_root_level}, btrfs_super_block,
			 q{root_level}, q{8});
mixin BTRFS_SETGET_STACK_FUNCS!(q{super_chunk_root}, btrfs_super_block,
			 q{chunk_root}, q{64});
mixin BTRFS_SETGET_STACK_FUNCS!(q{super_chunk_root_level}, btrfs_super_block,
			 q{chunk_root_level}, q{8});
mixin BTRFS_SETGET_STACK_FUNCS!(q{super_log_root}, btrfs_super_block,
			 q{log_root}, q{64});
mixin BTRFS_SETGET_STACK_FUNCS!(q{super_log_root_transid}, btrfs_super_block,
			 q{log_root_transid}, q{64});
mixin BTRFS_SETGET_STACK_FUNCS!(q{super_log_root_level}, btrfs_super_block,
			 q{log_root_level}, q{8});
mixin BTRFS_SETGET_STACK_FUNCS!(q{super_total_bytes}, btrfs_super_block,
			 q{total_bytes}, q{64});
mixin BTRFS_SETGET_STACK_FUNCS!(q{super_bytes_used}, btrfs_super_block,
			 q{bytes_used}, q{64});
mixin BTRFS_SETGET_STACK_FUNCS!(q{super_sectorsize}, btrfs_super_block,
			 q{sectorsize}, q{32});
mixin BTRFS_SETGET_STACK_FUNCS!(q{super_nodesize}, btrfs_super_block,
			 q{nodesize}, q{32});
mixin BTRFS_SETGET_STACK_FUNCS!(q{super_stripesize}, btrfs_super_block,
			 q{stripesize}, q{32});
mixin BTRFS_SETGET_STACK_FUNCS!(q{super_root_dir}, btrfs_super_block,
			 q{root_dir_objectid}, q{64});
mixin BTRFS_SETGET_STACK_FUNCS!(q{super_num_devices}, btrfs_super_block,
			 q{num_devices}, q{64});
mixin BTRFS_SETGET_STACK_FUNCS!(q{super_compat_flags}, btrfs_super_block,
			 q{compat_flags}, q{64});
mixin BTRFS_SETGET_STACK_FUNCS!(q{super_compat_ro_flags}, btrfs_super_block,
			 q{compat_ro_flags}, q{64});
mixin BTRFS_SETGET_STACK_FUNCS!(q{super_incompat_flags}, btrfs_super_block,
			 q{incompat_flags}, q{64});
mixin BTRFS_SETGET_STACK_FUNCS!(q{super_csum_type}, btrfs_super_block,
			 q{csum_type}, q{16});
mixin BTRFS_SETGET_STACK_FUNCS!(q{super_cache_generation}, btrfs_super_block,
			 q{cache_generation}, q{64});
mixin BTRFS_SETGET_STACK_FUNCS!(q{super_uuid_tree_generation}, btrfs_super_block,
			 q{uuid_tree_generation}, q{64});
mixin BTRFS_SETGET_STACK_FUNCS!(q{super_magic}, btrfs_super_block, q{magic}, q{64});

ulong btrfs_leaf_data(extent_buffer *l)
{
	return btrfs_leaf.items.offsetof;
}

/* struct btrfs_file_extent_item */
mixin BTRFS_SETGET_FUNCS!(q{file_extent_type}, btrfs_file_extent_item, q{type}, q{8});
mixin BTRFS_SETGET_STACK_FUNCS!(q{stack_file_extent_type}, btrfs_file_extent_item, q{type}, q{8});

ulong btrfs_file_extent_inline_start(btrfs_file_extent_item *e)
{
	ulong offset = cast(ulong)e;
	offset += btrfs_file_extent_item.disk_bytenr.offsetof;
	return offset;
}

u32 btrfs_file_extent_calc_inline_size(u32 datasize)
{
	return cast(u32)btrfs_file_extent_item.disk_bytenr.offsetof + datasize;
}

mixin BTRFS_SETGET_FUNCS!(q{file_extent_disk_bytenr}, btrfs_file_extent_item,
		   q{disk_bytenr}, q{64});
mixin BTRFS_SETGET_STACK_FUNCS!(q{stack_file_extent_disk_bytenr}, btrfs_file_extent_item,
		   q{disk_bytenr}, q{64});
mixin BTRFS_SETGET_FUNCS!(q{file_extent_generation}, btrfs_file_extent_item,
		   q{generation}, q{64});
mixin BTRFS_SETGET_STACK_FUNCS!(q{stack_file_extent_generation}, btrfs_file_extent_item,
		   q{generation}, q{64});
mixin BTRFS_SETGET_FUNCS!(q{file_extent_disk_num_bytes}, btrfs_file_extent_item,
		   q{disk_num_bytes}, q{64});
mixin BTRFS_SETGET_FUNCS!(q{file_extent_offset}, btrfs_file_extent_item,
		  q{offset}, q{64});
mixin BTRFS_SETGET_STACK_FUNCS!(q{stack_file_extent_offset}, btrfs_file_extent_item,
		  q{offset}, q{64});
mixin BTRFS_SETGET_FUNCS!(q{file_extent_num_bytes}, btrfs_file_extent_item,
		   q{num_bytes}, q{64});
mixin BTRFS_SETGET_STACK_FUNCS!(q{stack_file_extent_num_bytes}, btrfs_file_extent_item,
		   q{num_bytes}, q{64});
mixin BTRFS_SETGET_FUNCS!(q{file_extent_ram_bytes}, btrfs_file_extent_item,
		   q{ram_bytes}, q{64});
mixin BTRFS_SETGET_STACK_FUNCS!(q{stack_file_extent_ram_bytes}, btrfs_file_extent_item,
		   q{ram_bytes}, q{64});
mixin BTRFS_SETGET_FUNCS!(q{file_extent_compression}, btrfs_file_extent_item,
		   q{compression}, q{8});
mixin BTRFS_SETGET_STACK_FUNCS!(q{stack_file_extent_compression}, btrfs_file_extent_item,
		   q{compression}, q{8});
mixin BTRFS_SETGET_FUNCS!(q{file_extent_encryption}, btrfs_file_extent_item,
		   q{encryption}, q{8});
mixin BTRFS_SETGET_FUNCS!(q{file_extent_other_encoding}, btrfs_file_extent_item,
		   q{other_encoding}, q{16});

/* btrfs_qgroup_status_item */
mixin BTRFS_SETGET_FUNCS!(q{qgroup_status_version}, btrfs_qgroup_status_item,
		   q{version_}, q{64});
mixin BTRFS_SETGET_FUNCS!(q{qgroup_status_generation}, btrfs_qgroup_status_item,
		   q{generation}, q{64});
mixin BTRFS_SETGET_FUNCS!(q{qgroup_status_flags}, btrfs_qgroup_status_item,
		   q{flags}, q{64});
mixin BTRFS_SETGET_FUNCS!(q{qgroup_status_rescan}, btrfs_qgroup_status_item,
		   q{rescan}, q{64});

mixin BTRFS_SETGET_STACK_FUNCS!(q{stack_qgroup_status_version},
			 btrfs_qgroup_status_item, q{version_}, q{64});
mixin BTRFS_SETGET_STACK_FUNCS!(q{stack_qgroup_status_generation},
			 btrfs_qgroup_status_item, q{generation}, q{64});
mixin BTRFS_SETGET_STACK_FUNCS!(q{stack_qgroup_status_flags},
			 btrfs_qgroup_status_item, q{flags}, q{64});
mixin BTRFS_SETGET_STACK_FUNCS!(q{stack_qgroup_status_rescan},
			 btrfs_qgroup_status_item, q{rescan}, q{64});

/* btrfs_qgroup_info_item */
mixin BTRFS_SETGET_FUNCS!(q{qgroup_info_generation}, btrfs_qgroup_info_item,
		   q{generation}, q{64});
mixin BTRFS_SETGET_FUNCS!(q{qgroup_info_referenced}, btrfs_qgroup_info_item,
		   q{referenced}, q{64});
mixin BTRFS_SETGET_FUNCS!(q{qgroup_info_referenced_compressed},
		   btrfs_qgroup_info_item, q{referenced_compressed}, q{64});
mixin BTRFS_SETGET_FUNCS!(q{qgroup_info_exclusive}, btrfs_qgroup_info_item,
		   q{exclusive}, q{64});
mixin BTRFS_SETGET_FUNCS!(q{qgroup_info_exclusive_compressed},
		   btrfs_qgroup_info_item, q{exclusive_compressed}, q{64});

mixin BTRFS_SETGET_STACK_FUNCS!(q{stack_qgroup_info_generation},
			 btrfs_qgroup_info_item, q{generation}, q{64});
mixin BTRFS_SETGET_STACK_FUNCS!(q{stack_qgroup_info_referenced},
			 btrfs_qgroup_info_item, q{referenced}, q{64});
mixin BTRFS_SETGET_STACK_FUNCS!(q{stack_qgroup_info_referenced_compressed},
		   btrfs_qgroup_info_item, q{referenced_compressed}, q{64});
mixin BTRFS_SETGET_STACK_FUNCS!(q{stack_qgroup_info_exclusive},
			 btrfs_qgroup_info_item, q{exclusive}, q{64});
mixin BTRFS_SETGET_STACK_FUNCS!(q{stack_qgroup_info_exclusive_compressed},
		   btrfs_qgroup_info_item, q{exclusive_compressed}, q{64});

/* btrfs_qgroup_limit_item */
mixin BTRFS_SETGET_FUNCS!(q{qgroup_limit_flags}, btrfs_qgroup_limit_item,
		   q{flags}, q{64});
mixin BTRFS_SETGET_FUNCS!(q{qgroup_limit_max_referenced}, btrfs_qgroup_limit_item,
		   q{max_referenced}, q{64});
mixin BTRFS_SETGET_FUNCS!(q{qgroup_limit_max_exclusive}, btrfs_qgroup_limit_item,
		   q{max_exclusive}, q{64});
mixin BTRFS_SETGET_FUNCS!(q{qgroup_limit_rsv_referenced}, btrfs_qgroup_limit_item,
		   q{rsv_referenced}, q{64});
mixin BTRFS_SETGET_FUNCS!(q{qgroup_limit_rsv_exclusive}, btrfs_qgroup_limit_item,
		   q{rsv_exclusive}, q{64});

mixin BTRFS_SETGET_STACK_FUNCS!(q{stack_qgroup_limit_flags},
			 btrfs_qgroup_limit_item, q{flags}, q{64});
mixin BTRFS_SETGET_STACK_FUNCS!(q{stack_qgroup_limit_max_referenced},
			 btrfs_qgroup_limit_item, q{max_referenced}, q{64});
mixin BTRFS_SETGET_STACK_FUNCS!(q{stack_qgroup_limit_max_exclusive},
			 btrfs_qgroup_limit_item, q{max_exclusive}, q{64});
mixin BTRFS_SETGET_STACK_FUNCS!(q{stack_qgroup_limit_rsv_referenced},
			 btrfs_qgroup_limit_item, q{rsv_referenced}, q{64});
mixin BTRFS_SETGET_STACK_FUNCS!(q{stack_qgroup_limit_rsv_exclusive},
			 btrfs_qgroup_limit_item, q{rsv_exclusive}, q{64});

/* btrfs_balance_item */
mixin BTRFS_SETGET_FUNCS!(q{balance_item_flags}, btrfs_balance_item, q{flags}, q{64});

btrfs_disk_balance_args* btrfs_balance_item_data(
		extent_buffer *eb, btrfs_balance_item *bi)
{
	ulong offset = cast(ulong)bi;
	btrfs_balance_item *p;
	p = cast(btrfs_balance_item *)(eb.data.ptr + offset);
	return &p.data;
}

btrfs_disk_balance_args* btrfs_balance_item_meta(
		extent_buffer *eb, btrfs_balance_item *bi)
{
	ulong offset = cast(ulong)bi;
	btrfs_balance_item *p;
	p = cast(btrfs_balance_item *)(eb.data.ptr + offset);
	return &p.meta;
}

btrfs_disk_balance_args* btrfs_balance_item_sys(
		extent_buffer *eb, btrfs_balance_item *bi)
{
	ulong offset = cast(ulong)bi;
	btrfs_balance_item *p;
	p = cast(btrfs_balance_item *)(eb.data.ptr + offset);
	return &p.sys;
}

u64 btrfs_dev_stats_value()(const extent_buffer *eb,
					const btrfs_dev_stats_item *ptr,
					int index)
{
	u64 val;

	read_extent_buffer(eb, &val,
			   btrfs_dev_stats_item.values.offsetof +
			    (cast(ulong)ptr) + (index * u64.sizeof),
			   val.sizeof);
	return val;
}

/*
 * this returns the number of bytes used by the item on disk, minus the
 * size of any extent headers.  If a file is compressed on disk, this is
 * the compressed size
 */
u32 btrfs_file_extent_inline_item_len()(extent_buffer *eb,
						    btrfs_item *e)
{
       ulong offset;
       offset = btrfs_file_extent_item.disk_bytenr.offsetof;
       return cast(u32)(btrfs_item_size(eb, e) - offset);
}

/* struct btrfs_ioctl_search_header */
u64 btrfs_search_header_transid(btrfs_ioctl_search_header *sh)
{
	return get_unaligned_64(&sh.transid);
}

u64 btrfs_search_header_objectid(btrfs_ioctl_search_header *sh)
{
	return get_unaligned_64(&sh.objectid);
}

u64 btrfs_search_header_offset(btrfs_ioctl_search_header *sh)
{
	return get_unaligned_64(&sh.offset);
}

u32 btrfs_search_header_type(btrfs_ioctl_search_header *sh)
{
	return get_unaligned_32(&sh.type);
}

u32 btrfs_search_header_len(btrfs_ioctl_search_header *sh)
{
	return get_unaligned_32(&sh.len);
}

bool btrfs_fs_incompat(string opt)(btrfs_fs_info *fs_info)
{
	return __btrfs_fs_incompat(fs_info, mixin(q{BTRFS_FEATURE_INCOMPAT_} ~ opt));
}

bool __btrfs_fs_incompat(btrfs_fs_info *fs_info, u64 flag)
{
	btrfs_super_block *disk_super;
	disk_super = fs_info.super_copy;
	return !!(btrfs_super_incompat_flags(disk_super) & flag);
}

bool btrfs_fs_incompat_ro(string opt)(btrfs_fs_info *fs_info)
{
	return __btrfs_fs_incompat(fs_info, mixin(q{BTRFS_FEATURE_INCOMPAT_RO_} ~ opt));
}

int __btrfs_fs_compat_ro(btrfs_fs_info *fs_info, u64 flag)
{
	btrfs_super_block *disk_super;
	disk_super = fs_info.super_copy;
	return !!(btrfs_super_compat_ro_flags(disk_super) & flag);
}

/* helper function to cast into the data area of the leaf. */
type* btrfs_item_ptr(type)(extent_buffer *leaf, int slot)
{
	return cast(type *)(btrfs_leaf_data(leaf) +
		btrfs_item_offset_nr(leaf, slot));
}

ulong btrfs_item_ptr_offset()(extent_buffer *leaf, int slot)
{
	return cast(ulong)(btrfs_leaf_data(leaf) +
		btrfs_item_offset_nr(leaf, slot));
}

u64 btrfs_name_hash()(const char *name, int len)
{
	return crc32c((u32)~1, name, len);
}

/*
 * Figure the key offset of an extended inode ref
 */
u64 btrfs_extref_hash()(u64 parent_objectid, const char *name,
				    int len)
{
	return cast(u64)btrfs_crc32c(parent_objectid, name, len);
}

/* extent-tree.c */
int btrfs_reserve_extent(btrfs_trans_handle *trans,
			 btrfs_root *root,
			 u64 num_bytes, u64 empty_size,
			 u64 hint_byte, u64 search_end,
			 btrfs_key *ins, bool is_data);
int btrfs_fix_block_accounting(btrfs_trans_handle *trans);
void btrfs_pin_extent(btrfs_fs_info *fs_info, u64 bytenr, u64 num_bytes);
void btrfs_unpin_extent(btrfs_fs_info *fs_info,
			u64 bytenr, u64 num_bytes);
btrfs_block_group *btrfs_lookup_block_group(btrfs_fs_info *info,
						   u64 bytenr);
btrfs_block_group *btrfs_lookup_first_block_group(
						       btrfs_fs_info *info,
						       u64 bytenr);
extent_buffer *btrfs_alloc_free_block(btrfs_trans_handle *trans,
					btrfs_root *root,
					u32 blocksize, u64 root_objectid,
					btrfs_disk_key *key, int level,
					u64 hint, u64 empty_size);
int btrfs_lookup_extent_info(btrfs_trans_handle *trans,
			     btrfs_fs_info *fs_info, u64 bytenr,
			     u64 offset, int metadata, u64 *refs, u64 *flags);
int btrfs_set_block_flags(btrfs_trans_handle *trans, u64 bytenr,
			  int level, u64 flags);
int btrfs_inc_ref(btrfs_trans_handle *trans, btrfs_root *root,
		  extent_buffer *buf, int record_parent);
int btrfs_dec_ref(btrfs_trans_handle *trans, btrfs_root *root,
		  extent_buffer *buf, int record_parent);
int btrfs_free_tree_block(btrfs_trans_handle *trans,
			  btrfs_root *root,
			  extent_buffer *buf,
			  u64 parent, int last_ref);
int btrfs_free_extent(btrfs_trans_handle *trans,
		      btrfs_root *root,
		      u64 bytenr, u64 num_bytes, u64 parent,
		      u64 root_objectid, u64 owner, u64 offset);
void btrfs_finish_extent_commit(btrfs_trans_handle *trans);
int btrfs_inc_extent_ref(btrfs_trans_handle *trans,
			 btrfs_root *root,
			 u64 bytenr, u64 num_bytes, u64 parent,
			 u64 root_objectid, u64 owner, u64 offset);
int btrfs_update_extent_ref(btrfs_trans_handle *trans,
			    btrfs_root *root, u64 bytenr,
			    u64 orig_parent, u64 parent,
			    u64 root_objectid, u64 ref_generation,
			    u64 owner_objectid);
int btrfs_write_dirty_block_groups(btrfs_trans_handle *trans);
int update_space_info(btrfs_fs_info *info, u64 flags,
		      u64 total_bytes, u64 bytes_used,
		      btrfs_space_info **space_info);
int btrfs_free_block_groups(btrfs_fs_info *info);
int btrfs_read_block_groups(btrfs_fs_info *info);
btrfs_block_group *
btrfs_add_block_group(btrfs_fs_info *fs_info, u64 bytes_used, u64 type,
		      u64 chunk_offset, u64 size);
int btrfs_make_block_group(btrfs_trans_handle *trans,
			   btrfs_fs_info *fs_info, u64 bytes_used,
			   u64 type, u64 chunk_offset, u64 size);
int btrfs_make_block_groups(btrfs_trans_handle *trans,
			    btrfs_fs_info *fs_info);
int btrfs_update_block_group(btrfs_trans_handle *trans, u64 bytenr,
			     u64 num, int alloc, int mark_free);
int btrfs_record_file_extent(btrfs_trans_handle *trans,
			      btrfs_root *root, u64 objectid,
			      btrfs_inode_item *inode,
			      u64 file_pos, u64 disk_bytenr,
			      u64 num_bytes);
int btrfs_remove_block_group(btrfs_trans_handle *trans,
			     u64 bytenr, u64 len);
void free_excluded_extents(btrfs_fs_info *fs_info,
			   btrfs_block_group *cache);
int exclude_super_stripes(btrfs_fs_info *fs_info,
			  btrfs_block_group *cache);
u64 add_new_free_space(btrfs_block_group *block_group,
		       btrfs_fs_info *info, u64 start, u64 end);
u64 hash_extent_data_ref(u64 root_objectid, u64 owner, u64 offset);

/* ctree.c */
int btrfs_comp_cpu_keys(const btrfs_key *k1, const btrfs_key *k2);
int btrfs_del_ptr(btrfs_root *root, btrfs_path *path,
		int level, int slot);
btrfs_tree_block_status
btrfs_check_node(btrfs_fs_info *fs_info,
		 btrfs_disk_key *parent_key, extent_buffer *buf);
btrfs_tree_block_status
btrfs_check_leaf(btrfs_fs_info *fs_info,
		 btrfs_disk_key *parent_key, extent_buffer *buf);
void reada_for_search(btrfs_fs_info *fs_info, btrfs_path *path,
		      int level, int slot, u64 objectid);
extent_buffer *read_node_slot(btrfs_fs_info *fs_info,
				   extent_buffer *parent, int slot);
int btrfs_previous_item(btrfs_root *root,
			btrfs_path *path, u64 min_objectid,
			int type);
int btrfs_previous_extent_item(btrfs_root *root,
			btrfs_path *path, u64 min_objectid);
int btrfs_next_extent_item(btrfs_root *root,
			btrfs_path *path, u64 max_objectid);
int btrfs_cow_block(btrfs_trans_handle *trans,
		    btrfs_root *root, extent_buffer *buf,
		    extent_buffer *parent, int parent_slot,
		    extent_buffer **cow_ret);
int __btrfs_cow_block(btrfs_trans_handle *trans,
			     btrfs_root *root,
			     extent_buffer *buf,
			     extent_buffer *parent, int parent_slot,
			     extent_buffer **cow_ret,
			     u64 search_start, u64 empty_size);
int btrfs_copy_root(btrfs_trans_handle *trans,
		      btrfs_root *root,
		      extent_buffer *buf,
		      extent_buffer **cow_ret, u64 new_root_objectid);
int btrfs_create_root(btrfs_trans_handle *trans,
		      btrfs_fs_info *fs_info, u64 objectid);
int btrfs_extend_item(btrfs_root *root, btrfs_path *path,
		u32 data_size);
int btrfs_truncate_item(btrfs_root *root, btrfs_path *path,
			u32 new_size, int from_end);
int btrfs_split_item(btrfs_trans_handle *trans,
		     btrfs_root *root,
		     btrfs_path *path,
		     btrfs_key *new_key,
		     ulong split_offset);
int btrfs_search_slot(btrfs_trans_handle *trans,
		btrfs_root *root, const btrfs_key *key,
		btrfs_path *p, int ins_len, int cow);
int btrfs_search_slot_for_read(btrfs_root *root,
                               const btrfs_key *key,
                               btrfs_path *p, int find_higher,
                               int return_any);
int btrfs_bin_search(extent_buffer *eb, const btrfs_key *key,
		     int *slot);
int btrfs_find_item(btrfs_root *fs_root, btrfs_path *found_path,
		u64 iobjectid, u64 ioff, u8 key_type,
		btrfs_key *found_key);
void btrfs_release_path(btrfs_path *p);
void add_root_to_dirty_list(btrfs_root *root);
btrfs_path *btrfs_alloc_path();
void btrfs_free_path(btrfs_path *p);
void btrfs_init_path(btrfs_path *p);
int btrfs_del_items(btrfs_trans_handle *trans, btrfs_root *root,
		   btrfs_path *path, int slot, int nr);

int btrfs_del_item()(btrfs_trans_handle *trans,
				 btrfs_root *root,
				 btrfs_path *path)
{
	return btrfs_del_items(trans, root, path, path.slots[0], 1);
}

int btrfs_insert_item(btrfs_trans_handle *trans, btrfs_root
		      *root, btrfs_key *key, void *data, u32 data_size);
int btrfs_insert_empty_items(btrfs_trans_handle *trans,
			     btrfs_root *root,
			     btrfs_path *path,
			     btrfs_key *cpu_key, u32 *data_size, int nr);

int btrfs_insert_empty_item()(btrfs_trans_handle *trans,
					  btrfs_root *root,
					  btrfs_path *path,
					  btrfs_key *key,
					  u32 data_size)
{
	return btrfs_insert_empty_items(trans, root, path, key, &data_size, 1);
}

int btrfs_next_sibling_tree_block(btrfs_fs_info *fs_info,
				  btrfs_path *path);

/*
 * Walk up the tree as far as necessary to find the next leaf.
 *
 * returns 0 if it found something or 1 if there are no greater leaves.
 * returns < 0 on io errors.
 */
int btrfs_next_leaf()(btrfs_root *root,
				  btrfs_path *path)
{
	path.lowest_level = 0;
	return btrfs_next_sibling_tree_block(root.fs_info, path);
}

int btrfs_next_item()(btrfs_root *root,
				  btrfs_path *p)
{
	++p.slots[0];
	if (p.slots[0] >= btrfs_header_nritems(p.nodes[0]))
		return btrfs_next_leaf(root, p);
	return 0;
}

int btrfs_prev_leaf(btrfs_root *root, btrfs_path *path);
int btrfs_leaf_free_space(extent_buffer *leaf);
void btrfs_fixup_low_keys(btrfs_root *root, btrfs_path *path,
			  btrfs_disk_key *key, int level);
int btrfs_set_item_key_safe(btrfs_root *root, btrfs_path *path,
			    btrfs_key *new_key);
void btrfs_set_item_key_unsafe(btrfs_root *root,
			       btrfs_path *path,
			       btrfs_key *new_key);

u16 btrfs_super_csum_size(const btrfs_super_block *s);
const(char)*btrfs_super_csum_name(u16 csum_type);
u16 btrfs_csum_type_size(u16 csum_type);
size_t btrfs_super_num_csums();

/* root-item.c */
int btrfs_add_root_ref(btrfs_trans_handle *trans,
		       btrfs_root *tree_root,
		       u64 root_id, u8 type, u64 ref_id,
		       u64 dirid, u64 sequence,
		       const char *name, int name_len);
int btrfs_insert_root(btrfs_trans_handle *trans, btrfs_root
		      *root, btrfs_key *key, btrfs_root_item
		      *item);
int btrfs_del_root(btrfs_trans_handle *trans, btrfs_root *root,
		   btrfs_key *key);
int btrfs_update_root(btrfs_trans_handle *trans, btrfs_root
		      *root, btrfs_key *key, btrfs_root_item
		      *item);
int btrfs_find_last_root(btrfs_root *root, u64 objectid,
			 btrfs_root_item *item, btrfs_key *key);
/* dir-item.c */
int btrfs_insert_dir_item(btrfs_trans_handle *trans, btrfs_root
			  *root, const char *name, int name_len, u64 dir,
			  btrfs_key *location, u8 type, u64 index);
btrfs_dir_item *btrfs_lookup_dir_item(btrfs_trans_handle *trans,
					     btrfs_root *root,
					     btrfs_path *path, u64 dir,
					     const char *name, int name_len,
					     int mod);
btrfs_dir_item *btrfs_lookup_dir_index_item(btrfs_trans_handle *trans,
					btrfs_root *root,
					btrfs_path *path, u64 dir,
					u64 objectid, const char *name, int name_len,
					int mod);
int btrfs_delete_one_dir_name(btrfs_trans_handle *trans,
			      btrfs_root *root,
			      btrfs_path *path,
			      btrfs_dir_item *di);
int btrfs_insert_xattr_item(btrfs_trans_handle *trans,
			    btrfs_root *root, const char *name,
			    u16 name_len, const void *data, u16 data_len,
			    u64 dir);
btrfs_dir_item *btrfs_match_dir_item_name(btrfs_root *root,
			      btrfs_path *path,
			      const char *name, int name_len);

/* inode-item.c */
int btrfs_insert_inode_ref(btrfs_trans_handle *trans,
			   btrfs_root *root,
			   const char *name, int name_len,
			   u64 inode_objectid, u64 ref_objectid, u64 index);
int btrfs_insert_inode(btrfs_trans_handle *trans, btrfs_root
		       *root, u64 objectid, btrfs_inode_item
		       *inode_item);
int btrfs_lookup_inode(btrfs_trans_handle *trans, btrfs_root
		       *root, btrfs_path *path,
		       btrfs_key *location, int mod);
btrfs_inode_extref *btrfs_lookup_inode_extref(btrfs_trans_handle
		*trans, btrfs_path *path, btrfs_root *root,
		u64 ino, u64 parent_ino, u64 index, const char *name,
		int namelen, int ins_len);
int btrfs_del_inode_extref(btrfs_trans_handle *trans,
			   btrfs_root *root,
			   const char *name, int name_len,
			   u64 inode_objectid, u64 ref_objectid,
			   u64 *index);
int btrfs_insert_inode_extref(btrfs_trans_handle *trans,
			      btrfs_root *root,
			      const char *name, int name_len,
			      u64 inode_objectid, u64 ref_objectid, u64 index);
btrfs_inode_ref *btrfs_lookup_inode_ref(btrfs_trans_handle *trans,
		btrfs_root *root, btrfs_path *path,
		const char *name, int namelen, u64 ino, u64 parent_ino,
		int ins_len);
int btrfs_del_inode_ref(btrfs_trans_handle *trans,
			btrfs_root *root, const char *name, int name_len,
			u64 ino, u64 parent_ino, u64 *index);

/* file-item.c */
int btrfs_del_csums(btrfs_trans_handle *trans, u64 bytenr, u64 len);
int btrfs_insert_file_extent(btrfs_trans_handle *trans,
			     btrfs_root *root,
			     u64 objectid, u64 pos, u64 offset,
			     u64 disk_num_bytes,
			     u64 num_bytes);
int btrfs_insert_inline_extent(btrfs_trans_handle *trans,
				btrfs_root *root, u64 objectid,
				u64 offset, const char *buffer, size_t size);
int btrfs_csum_file_block(btrfs_trans_handle *trans,
			  btrfs_root *root, u64 alloc_end,
			  u64 bytenr, char *data, size_t len);
int btrfs_csum_truncate(btrfs_trans_handle *trans,
			btrfs_root *root, btrfs_path *path,
			u64 isize);

/* uuid-tree.c, interface for mounted mounted filesystem */
int btrfs_lookup_uuid_subvol_item(int fd, const u8 *uuid, u64 *subvol_id);
int btrfs_lookup_uuid_received_subvol_item(int fd, const u8 *uuid,
					   u64 *subvol_id);

/* uuid-tree.c, interface for unmounte filesystem */
int btrfs_uuid_tree_add(btrfs_trans_handle *trans, u8 *uuid, u8 type,
			u64 subvol_id_cpu);

int is_fstree(u64 rootid)
{
	if (rootid == BTRFS_FS_TREE_OBJECTID ||
	    cast(long)rootid >= cast(long)BTRFS_FIRST_FREE_OBJECTID)
		return 1;
	return 0;
}

void btrfs_uuid_to_key(const u8 *uuid, btrfs_key *key);

/* inode.c */
int check_dir_conflict(btrfs_root *root, char *name, int namelen,
		u64 dir, u64 index);
int btrfs_new_inode(btrfs_trans_handle *trans, btrfs_root *root,
		u64 ino, u32 mode);
int btrfs_change_inode_flags(btrfs_trans_handle *trans,
			     btrfs_root *root, u64 ino, u64 flags);
int btrfs_add_link(btrfs_trans_handle *trans, btrfs_root *root,
		   u64 ino, u64 parent_ino, char *name, int namelen,
		   u8 type, u64 *index, int add_backref, int ignore_existed);
int btrfs_unlink(btrfs_trans_handle *trans, btrfs_root *root,
		 u64 ino, u64 parent_ino, u64 index, const char *name,
		 int namelen, int add_orphan);
int btrfs_add_orphan_item(btrfs_trans_handle *trans,
			  btrfs_root *root, btrfs_path *path,
			  u64 ino);
int btrfs_mkdir(btrfs_trans_handle *trans, btrfs_root *root,
		char *name, int namelen, u64 parent_ino, u64 *ino, int mode);
btrfs_root *btrfs_mksubvol(btrfs_root *root, const char *base,
				  u64 root_objectid, bool convert);
int btrfs_find_free_objectid(btrfs_trans_handle *trans,
			     btrfs_root *fs_root,
			     u64 dirid, u64 *objectid);

/* file.c */
int btrfs_get_extent(btrfs_trans_handle *trans,
		     btrfs_root *root,
		     btrfs_path *path,
		     u64 ino, u64 offset, u64 len, int ins_len);
int btrfs_punch_hole(btrfs_trans_handle *trans,
		     btrfs_root *root,
		     u64 ino, u64 offset, u64 len);
int btrfs_read_file(btrfs_root *root, u64 ino, u64 start, int len,
		    char *dest);

/* extent-tree.c */
int btrfs_run_delayed_refs(btrfs_trans_handle *trans, ulong nr);
