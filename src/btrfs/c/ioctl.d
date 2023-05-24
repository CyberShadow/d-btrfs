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

/// D translation of ioctl.h from btrfs-progs (v5.9)
module btrfs.c.ioctl;

extern(C):

import core.sys.posix.sys.ioctl;

import btrfs.c.kerncompat;

import btrfs.c.kernel_shared.ctree : BTRFS_LABEL_SIZE;

enum BTRFS_IOCTL_MAGIC = 0x94;
enum BTRFS_VOL_NAME_MAX = 255;

/* this should be 4k */
enum BTRFS_PATH_NAME_MAX = 4087;
struct btrfs_ioctl_vol_args {
	__s64 fd;
	ubyte[BTRFS_PATH_NAME_MAX + 1] name;
}
// static assert((btrfs_ioctl_vol_args).sizeof == 4096);

enum BTRFS_DEVICE_PATH_NAME_MAX = 1024;

enum BTRFS_SUBVOL_CREATE_ASYNC	= (1UL << 0);
enum BTRFS_SUBVOL_RDONLY		= (1UL << 1);
enum BTRFS_SUBVOL_QGROUP_INHERIT	= (1UL << 2);
enum BTRFS_DEVICE_SPEC_BY_ID		= (1UL << 3);
enum BTRFS_SUBVOL_SPEC_BY_ID		= (1UL << 4);

enum BTRFS_VOL_ARG_V2_FLAGS_SUPPORTED		=
			(BTRFS_SUBVOL_CREATE_ASYNC |
			BTRFS_SUBVOL_RDONLY |
			BTRFS_SUBVOL_QGROUP_INHERIT |
			BTRFS_DEVICE_SPEC_BY_ID |
			BTRFS_SUBVOL_SPEC_BY_ID);

enum BTRFS_FSID_SIZE = 16;
public import btrfs.c.kernel_shared.ctree : BTRFS_UUID_SIZE;

enum BTRFS_QGROUP_INHERIT_SET_LIMITS	= (1UL << 0);

struct btrfs_qgroup_limit {
	__u64	flags;
	__u64	max_referenced;
	__u64	max_exclusive;
	__u64	rsv_referenced;
	__u64	rsv_exclusive;
}
// static assert((btrfs_qgroup_limit).sizeof == 40);

struct btrfs_qgroup_inherit {
	__u64	flags;
	__u64	num_qgroups;
	__u64	num_ref_copies;
	__u64	num_excl_copies;
	btrfs_qgroup_limit lim;
	__u64[0]	qgroups;
}
// static assert((btrfs_qgroup_inherit).sizeof == 72);

struct btrfs_ioctl_qgroup_limit_args {
	__u64	qgroupid;
	btrfs_qgroup_limit lim;
}
// static assert((btrfs_ioctl_qgroup_limit_args).sizeof == 48);

enum BTRFS_SUBVOL_NAME_MAX = 4039;
struct btrfs_ioctl_vol_args_v2 {
	__s64 fd;
	__u64 transid;
	__u64 flags;
	union {
		struct {
			__u64 size;
			btrfs_qgroup_inherit /*__user*/ *qgroup_inherit;
		}
		__u64[4] unused;
	}
	union {
		char[BTRFS_SUBVOL_NAME_MAX + 1] name;
		__u64 devid;
		__u64 subvolid;
	}
}
// static assert((btrfs_ioctl_vol_args_v2).sizeof == 4096);

/*
 * structure to report errors and progress to userspace, either as a
 * result of a finished scrub, a canceled scrub or a progress inquiry
 */
struct btrfs_scrub_progress {
	__u64 data_extents_scrubbed;	/* # of data extents scrubbed */
	__u64 tree_extents_scrubbed;	/* # of tree extents scrubbed */
	__u64 data_bytes_scrubbed;	/* # of data bytes scrubbed */
	__u64 tree_bytes_scrubbed;	/* # of tree bytes scrubbed */
	__u64 read_errors;		/* # of read errors encountered (EIO) */
	__u64 csum_errors;		/* # of failed csum checks */
	__u64 verify_errors;		/* # of occurrences, where the metadata
					 * of a tree block did not match the
					 * expected values, like generation or
					 * logical */
	__u64 no_csum;			/* # of 4k data block for which no csum
					 * is present, probably the result of
					 * data written with nodatasum */
	__u64 csum_discards;		/* # of csum for which no data was found
					 * in the extent tree. */
	__u64 super_errors;		/* # of bad super blocks encountered */
	__u64 malloc_errors;		/* # of internal kmalloc errors. These
					 * will likely cause an incomplete
					 * scrub */
	__u64 uncorrectable_errors;	/* # of errors where either no intact
					 * copy was found or the writeback
					 * failed */
	__u64 corrected_errors;		/* # of errors corrected */
	__u64 last_physical;		/* last physical address scrubbed. In
					 * case a scrub was aborted, this can
					 * be used to restart the scrub */
	__u64 unverified_errors;	/* # of occurrences where a read for a
					 * full (64k) bio failed, but the re-
					 * check succeeded for each 4k piece.
					 * Intermittent error. */
}

enum BTRFS_SCRUB_READONLY	= 1;
struct btrfs_ioctl_scrub_args {
	__u64 devid;				/* in */
	__u64 start;				/* in */
	__u64 end;				/* in */
	__u64 flags;				/* in */
	btrfs_scrub_progress progress;	/* out */
	/* pad to 1k */
	__u64[(1024-32-(btrfs_scrub_progress).sizeof)/8] unused;
}
// static assert((btrfs_ioctl_scrub_args).sizeof == 1024);

enum BTRFS_IOCTL_DEV_REPLACE_CONT_READING_FROM_SRCDEV_MODE_ALWAYS	= 0;
enum BTRFS_IOCTL_DEV_REPLACE_CONT_READING_FROM_SRCDEV_MODE_AVOID	= 1;
struct btrfs_ioctl_dev_replace_start_params {
	__u64 srcdevid;	/* in, if 0, use srcdev_name instead */
	__u64 cont_reading_from_srcdev_mode;	/* in, see #define
						 * above */
	__u8[BTRFS_DEVICE_PATH_NAME_MAX + 1] srcdev_name;	/* in */
	__u8[BTRFS_DEVICE_PATH_NAME_MAX + 1] tgtdev_name;	/* in */
}
// static assert((btrfs_ioctl_dev_replace_start_params).sizeof == 2072);

enum BTRFS_IOCTL_DEV_REPLACE_STATE_NEVER_STARTED	= 0;
enum BTRFS_IOCTL_DEV_REPLACE_STATE_STARTED		= 1;
enum BTRFS_IOCTL_DEV_REPLACE_STATE_FINISHED		= 2;
enum BTRFS_IOCTL_DEV_REPLACE_STATE_CANCELED		= 3;
enum BTRFS_IOCTL_DEV_REPLACE_STATE_SUSPENDED		= 4;
struct btrfs_ioctl_dev_replace_status_params {
	__u64 replace_state;	/* out, see #define above */
	__u64 progress_1000;	/* out, 0 <= x <= 1000 */
	__u64 time_started;	/* out, seconds since 1-Jan-1970 */
	__u64 time_stopped;	/* out, seconds since 1-Jan-1970 */
	__u64 num_write_errors;	/* out */
	__u64 num_uncorrectable_read_errors;	/* out */
}
// static assert((btrfs_ioctl_dev_replace_status_params).sizeof == 48);

enum BTRFS_IOCTL_DEV_REPLACE_CMD_START			= 0;
enum BTRFS_IOCTL_DEV_REPLACE_CMD_STATUS			= 1;
enum BTRFS_IOCTL_DEV_REPLACE_CMD_CANCEL			= 2;
enum BTRFS_IOCTL_DEV_REPLACE_RESULT_NO_RESULT		= -1;
enum BTRFS_IOCTL_DEV_REPLACE_RESULT_NO_ERROR			= 0;
enum BTRFS_IOCTL_DEV_REPLACE_RESULT_NOT_STARTED		= 1;
enum BTRFS_IOCTL_DEV_REPLACE_RESULT_ALREADY_STARTED		= 2;
enum BTRFS_IOCTL_DEV_REPLACE_RESULT_SCRUB_INPROGRESS		= 3;
struct btrfs_ioctl_dev_replace_args {
	__u64 cmd;	/* in */
	__u64 result;	/* out */

	union {
		btrfs_ioctl_dev_replace_start_params start;
		btrfs_ioctl_dev_replace_status_params status;
	}	/* in/out */

	__u64[64] spare;
}
// static assert((btrfs_ioctl_dev_replace_args).sizeof == 2600);

struct btrfs_ioctl_dev_info_args {
	__u64 devid;				/* in/out */
	__u8[BTRFS_UUID_SIZE] uuid;		/* in/out */
	__u64 bytes_used;			/* out */
	__u64 total_bytes;			/* out */
	__u64[379] unused;			/* pad to 4k */
	__u8[BTRFS_DEVICE_PATH_NAME_MAX] path;	/* out */
}
// static assert((btrfs_ioctl_dev_info_args).sizeof == 4096);

struct btrfs_ioctl_fs_info_args {
	__u64 max_id;				/* out */
	__u64 num_devices;			/* out */
	__u8[BTRFS_FSID_SIZE] fsid;		/* out */
	__u32 nodesize;				/* out */
	__u32 sectorsize;			/* out */
	__u32 clone_alignment;			/* out */
	__u32 reserved32;
	__u64[122] reserved;			/* pad to 1k */
}
// static assert((btrfs_ioctl_fs_info_args).sizeof == 1024);

struct btrfs_ioctl_feature_flags {
	__u64 compat_flags;
	__u64 compat_ro_flags;
	__u64 incompat_flags;
}
// static assert((btrfs_ioctl_feature_flags).sizeof == 24);

/* balance control ioctl modes */
enum BTRFS_BALANCE_CTL_PAUSE		= 1;
enum BTRFS_BALANCE_CTL_CANCEL	= 2;
enum BTRFS_BALANCE_CTL_RESUME	= 3;

/*
 * this is packed, because it should be exactly the same as its disk
 * byte order counterpart (btrfs_disk_balance_args)
 */
struct btrfs_balance_args {
align(1):
	__u64 profiles;

	/*
	 * usage filter
	 * BTRFS_BALANCE_ARGS_USAGE with a single value means '0..N'
	 * BTRFS_BALANCE_ARGS_USAGE_RANGE - range syntax, min..max
	 */
	union {
		__u64 usage;
		struct {
			__u32 usage_min;
			__u32 usage_max;
		}
	}

	__u64 devid;
	__u64 pstart;
	__u64 pend;
	__u64 vstart;
	__u64 vend;

	__u64 target;

	__u64 flags;

	/*
	 * BTRFS_BALANCE_ARGS_LIMIT with value 'limit'
	 * BTRFS_BALANCE_ARGS_LIMIT_RANGE - the extend version can use minimum
	 * and maximum
	 */
	union {
		__u64 limit;		/* limit number of processed chunks */
		struct {
			__u32 limit_min;
			__u32 limit_max;
		}
	}
	__u32 stripes_min;
	__u32 stripes_max;
	__u64[6] unused;
}

/* report balance progress to userspace */
struct btrfs_balance_progress {
	__u64 expected;		/* estimated # of chunks that will be
				 * relocated to fulfil the request */
	__u64 considered;	/* # of chunks we have considered so far */
	__u64 completed;	/* # of chunks relocated so far */
}

enum BTRFS_BALANCE_STATE_RUNNING	= (1UL << 0);
enum BTRFS_BALANCE_STATE_PAUSE_REQ	= (1UL << 1);
enum BTRFS_BALANCE_STATE_CANCEL_REQ	= (1UL << 2);

struct btrfs_ioctl_balance_args {
	__u64 flags;				/* in/out */
	__u64 state;				/* out */

	btrfs_balance_args data;		/* in/out */
	btrfs_balance_args meta;		/* in/out */
	btrfs_balance_args sys;		/* in/out */

	btrfs_balance_progress stat;	/* out */

	__u64[72] unused;			/* pad to 1k */
}
// static assert((btrfs_ioctl_balance_args).sizeof == 1024);

enum BTRFS_INO_LOOKUP_PATH_MAX = 4080;
struct btrfs_ioctl_ino_lookup_args {
	__u64 treeid;
	__u64 objectid;
	char[BTRFS_INO_LOOKUP_PATH_MAX] name;
}
// static assert((btrfs_ioctl_ino_lookup_args).sizeof == 4096);

enum BTRFS_INO_LOOKUP_USER_PATH_MAX	= (4080 - BTRFS_VOL_NAME_MAX - 1);
struct btrfs_ioctl_ino_lookup_user_args {
	/* in, inode number containing the subvolume of 'subvolid' */
	__u64 dirid;
	/* in */
	__u64 treeid;
	/* out, name of the subvolume of 'treeid' */
	char[BTRFS_VOL_NAME_MAX + 1] name;
	/*
	 * out, constructed path from the directory with which the ioctl is
	 * called to dirid
	 */
	char[BTRFS_INO_LOOKUP_USER_PATH_MAX] path;
}
// static assert((btrfs_ioctl_ino_lookup_user_args).sizeof == 4096);

struct btrfs_ioctl_search_key {
	/* which root are we searching.  0 is the tree of tree roots */
	__u64 tree_id;

	/* keys returned will be >= min and <= max */
	__u64 min_objectid;
	__u64 max_objectid;

	/* keys returned will be >= min and <= max */
	__u64 min_offset;
	__u64 max_offset;

	/* max and min transids to search for */
	__u64 min_transid;
	__u64 max_transid;

	/* keys returned will be >= min and <= max */
	__u32 min_type;
	__u32 max_type;

	/*
	 * how many items did userland ask for, and how many are we
	 * returning
	 */
	__u32 nr_items;

	/* align to 64 bits */
	__u32 unused;

	/* some extra for later */
	__u64 unused1;
	__u64 unused2;
	__u64 unused3;
	__u64 unused4;
}

struct btrfs_ioctl_search_header {
	__u64 transid;
	__u64 objectid;
	__u64 offset;
	__u32 type;
	__u32 len;
} /*__attribute__((may_alias))*/

enum BTRFS_SEARCH_ARGS_BUFSIZE = (4096 - (btrfs_ioctl_search_key).sizeof);
/*
 * the buf is an array of search headers where
 * each header is followed by the actual item
 * the type field is expanded to 32 bits for alignment
 */
struct btrfs_ioctl_search_args {
	btrfs_ioctl_search_key key;
	ubyte[BTRFS_SEARCH_ARGS_BUFSIZE] buf;
}

/*
 * Extended version of TREE_SEARCH ioctl that can return more than 4k of bytes.
 * The allocated size of the buffer is set in buf_size.
 */
struct btrfs_ioctl_search_args_v2 {
	btrfs_ioctl_search_key key;        /* in/out - search parameters */
	__u64 buf_size;			   /* in - size of buffer
					    * out - on EOVERFLOW: needed size
					    *       to store item */
	__u64[0] buf;                      /* out - found items */
}
// static assert((btrfs_ioctl_search_args_v2).sizeof == 112);

/* With a @src_length of zero, the range from @src_offset->EOF is cloned! */
struct btrfs_ioctl_clone_range_args {
	__s64 src_fd;
	__u64 src_offset, src_length;
	__u64 dest_offset;
}
// static assert((btrfs_ioctl_clone_range_args).sizeof == 32);

/* flags for the defrag range ioctl */
enum BTRFS_DEFRAG_RANGE_COMPRESS = 1;
enum BTRFS_DEFRAG_RANGE_START_IO = 2;

enum BTRFS_SAME_DATA_DIFFERS	= 1;
/* For extent-same ioctl */
struct btrfs_ioctl_same_extent_info {
	__s64 fd;		/* in - destination file */
	__u64 logical_offset;	/* in - start of extent in destination */
	__u64 bytes_deduped;	/* out - total # of bytes we were able
				 * to dedupe from this file */
	/* status of this dedupe operation:
	 * 0 if dedup succeeds
	 * < 0 for error
	 * == BTRFS_SAME_DATA_DIFFERS if data differs
	 */
	__s32 status;		/* out - see above description */
	__u32 reserved;
}

struct btrfs_ioctl_same_args {
	__u64 logical_offset;	/* in - start of extent in source */
	__u64 length;		/* in - length of extent */
	__u16 dest_count;	/* in - total elements in info array */
	__u16 reserved1;
	__u32 reserved2;
	btrfs_ioctl_same_extent_info[0] info;
}
// static assert((btrfs_ioctl_same_args).sizeof == 24);

struct btrfs_ioctl_defrag_range_args {
	/* start of the defrag operation */
	__u64 start;

	/* number of bytes to defrag, use (u64)-1 to say all */
	__u64 len;

	/*
	 * flags for the operation, which can include turning
	 * on compression for this one defrag
	 */
	__u64 flags;

	/*
	 * any extent bigger than this will be considered
	 * already defragged.  Use 0 to take the kernel default
	 * Use 1 to say every single extent must be rewritten
	 */
	__u32 extent_thresh;

	/*
	 * which compression method to use if turning on compression
	 * for this defrag operation.  If unspecified, zlib will
	 * be used
	 */
	__u32 compress_type;

	/* spare for later */
	__u32[4] unused;
}
// static assert((btrfs_ioctl_defrag_range_args).sizeof == 48);

struct btrfs_ioctl_space_info {
	__u64 flags;
	__u64 total_bytes;
	__u64 used_bytes;
}

struct btrfs_ioctl_space_args {
	__u64 space_slots;
	__u64 total_spaces;
	btrfs_ioctl_space_info[0] spaces;
}
// static assert((btrfs_ioctl_space_args).sizeof == 16);

struct btrfs_data_container {
	__u32	bytes_left;	/* out -- bytes not needed to deliver output */
	__u32	bytes_missing;	/* out -- additional bytes needed for result */
	__u32	elem_cnt;	/* out */
	__u32	elem_missed;	/* out */
	__u64[0]	val;		/* out */
}

struct btrfs_ioctl_ino_path_args {
	__u64				inum;		/* in */
	__u64				size;		/* in */
	__u64[4]				reserved;
	/* struct btrfs_data_container	*fspath;	   out */
	__u64				fspath;		/* out */
}
// static assert((btrfs_ioctl_ino_path_args).sizeof == 56);

struct btrfs_ioctl_logical_ino_args {
	__u64				logical;	/* in */
	__u64				size;		/* in */
	__u64[3]				reserved;
	__u64				flags;		/* in */
	/* struct btrfs_data_container	*inodes;	out   */
	__u64				inodes;
}

/*
 * Return every ref to the extent, not just those containing logical block.
 * Requires logical == extent bytenr.
 */
enum BTRFS_LOGICAL_INO_ARGS_IGNORE_OFFSET    = (1UL << 0);

enum btrfs_dev_stat_values {
	/* disk I/O failure stats */
	BTRFS_DEV_STAT_WRITE_ERRS, /* EIO or EREMOTEIO from lower layers */
	BTRFS_DEV_STAT_READ_ERRS, /* EIO or EREMOTEIO from lower layers */
	BTRFS_DEV_STAT_FLUSH_ERRS, /* EIO or EREMOTEIO from lower layers */

	/* stats for indirect indications for I/O failures */
	BTRFS_DEV_STAT_CORRUPTION_ERRS, /* checksum error, bytenr error or
					 * contents is illegal: this is an
					 * indication that the block was damaged
					 * during read or write, or written to
					 * wrong location or read from wrong
					 * location */
	BTRFS_DEV_STAT_GENERATION_ERRS, /* an indication that blocks have not
					 * been written */

	BTRFS_DEV_STAT_VALUES_MAX
}

/* Reset statistics after reading; needs SYS_ADMIN capability */
enum	BTRFS_DEV_STATS_RESET		= (1UL << 0);

struct btrfs_ioctl_get_dev_stats {
	__u64 devid;				/* in */
	__u64 nr_items;				/* in/out */
	__u64 flags;				/* in/out */

	/* out values: */
	__u64[btrfs_dev_stat_values.BTRFS_DEV_STAT_VALUES_MAX] values;

	__u64[128 - 2 - btrfs_dev_stat_values.BTRFS_DEV_STAT_VALUES_MAX] unused; /* pad to 1k + 8B */
}
// static assert((btrfs_ioctl_get_dev_stats).sizeof == 1032);

/* BTRFS_IOC_SNAP_CREATE is no longer used by the btrfs command */
enum BTRFS_QUOTA_CTL_ENABLE	= 1;
enum BTRFS_QUOTA_CTL_DISABLE	= 2;
/* 3 has formerly been reserved for BTRFS_QUOTA_CTL_RESCAN */
struct btrfs_ioctl_quota_ctl_args {
	__u64 cmd;
	__u64 status;
}
// static assert((btrfs_ioctl_quota_ctl_args).sizeof == 16);

struct btrfs_ioctl_quota_rescan_args {
	__u64	flags;
	__u64   progress;
	__u64[6]   reserved;
}
// static assert((btrfs_ioctl_quota_rescan_args).sizeof == 64);

struct btrfs_ioctl_qgroup_assign_args {
	__u64 assign;
	__u64 src;
	__u64 dst;
}

struct btrfs_ioctl_qgroup_create_args {
	__u64 create;
	__u64 qgroupid;
}
// static assert((btrfs_ioctl_qgroup_create_args).sizeof == 16);

struct btrfs_ioctl_timespec {
	__u64 sec;
	__u32 nsec;
}

struct btrfs_ioctl_received_subvol_args {
	char[BTRFS_UUID_SIZE]	uuid;	/* in */
	__u64	stransid;		/* in */
	__u64	rtransid;		/* out */
	btrfs_ioctl_timespec stime; /* in */
	btrfs_ioctl_timespec rtime; /* out */
	__u64	flags;			/* in */
	__u64[16]	reserved;		/* in */
}
// static assert((btrfs_ioctl_received_subvol_args).sizeof == 200);

/*
 * If we have a 32-bit userspace and 64-bit kernel, then the UAPI
 * structures are incorrect, as the timespec structure from userspace
 * is 4 bytes too small. We define these alternatives here for backward
 * compatibility, the kernel understands both values.
 */

/*
 * Structure size is different on 32bit and 64bit, has some padding if the
 * structure is embedded. Packing makes sure the size is same on both, but will
 * be misaligned on 64bit.
 *
 * NOTE: do not use in your code, this is for testing only
 */
struct btrfs_ioctl_timespec_32 {
align(1):
	__u64 sec;
	__u32 nsec;
}

struct btrfs_ioctl_received_subvol_args_32 {
align(1):
	char[BTRFS_UUID_SIZE]	uuid;	/* in */
	__u64	stransid;		/* in */
	__u64	rtransid;		/* out */
	btrfs_ioctl_timespec_32 stime; /* in */
	btrfs_ioctl_timespec_32 rtime; /* out */
	__u64	flags;			/* in */
	__u64[16]	reserved;		/* in */
}
// static assert((btrfs_ioctl_received_subvol_args_32).sizeof == 192);

enum BTRFS_IOC_SET_RECEIVED_SUBVOL_32_COMPAT_DEFINED = 1;

/*
 * Caller doesn't want file data in the send stream, even if the
 * search of clone sources doesn't find an extent. UPDATE_EXTENT
 * commands will be sent instead of WRITE commands.
 */
enum BTRFS_SEND_FLAG_NO_FILE_DATA		= 0x1;

/*
 * Do not add the leading stream header. Used when multiple snapshots
 * are sent back to back.
 */
enum BTRFS_SEND_FLAG_OMIT_STREAM_HEADER	= 0x2;

/*
 * Omit the command at the end of the stream that indicated the end
 * of the stream. This option is used when multiple snapshots are
 * sent back to back.
 */
enum BTRFS_SEND_FLAG_OMIT_END_CMD		= 0x4;

enum BTRFS_SEND_FLAG_MASK =
	(BTRFS_SEND_FLAG_NO_FILE_DATA |
	 BTRFS_SEND_FLAG_OMIT_STREAM_HEADER |
	 BTRFS_SEND_FLAG_OMIT_END_CMD);

struct btrfs_ioctl_send_args {
	__s64 send_fd;			/* in */
	__u64 clone_sources_count;	/* in */
	__u64 /*__user*/ *clone_sources;	/* in */
	__u64 parent_root;		/* in */
	__u64 flags;			/* in */
	__u64[4] reserved;		/* in */
}
/*
 * Size of structure depends on pointer width, was not caught in the early
 * days.  Kernel handles pointer width differences transparently.
 */
// static assert((__u64 *).sizeof == 8
// 	     ? (btrfs_ioctl_send_args).sizeof == 72
// 	     : ((void *).sizeof == 4
// 		? (btrfs_ioctl_send_args).sizeof == 68
// 		: 0));

/*
 * Different pointer width leads to structure size change. Kernel should accept
 * both ioctl values (derived from the structures) for backward compatibility.
 * Size of this structure is same on 32bit and 64bit though.
 *
 * NOTE: do not use in your code, this is for testing only
 */
struct btrfs_ioctl_send_args_64 {
align(1):
	__s64 send_fd;			/* in */
	__u64 clone_sources_count;	/* in */
	union {
		__u64 /*__user*/ *clone_sources;	/* in */
		__u64 __clone_sources_alignment;
	}
	__u64 parent_root;		/* in */
	__u64 flags;			/* in */
	__u64[4] reserved;		/* in */
}
// static assert((btrfs_ioctl_send_args_64).sizeof == 72);

enum BTRFS_IOC_SEND_64_COMPAT_DEFINED = 1;

/*
 * Information about a fs tree root.
 *
 * All items are filled by the ioctl
 */
struct btrfs_ioctl_get_subvol_info_args {
	/* Id of this subvolume */
	__u64 treeid;

	/* Name of this subvolume, used to get the real name at mount point */
	char[BTRFS_VOL_NAME_MAX + 1] name;

	/*
	 * Id of the subvolume which contains this subvolume.
	 * Zero for top-level subvolume or a deleted subvolume.
	 */
	__u64 parent_id;

	/*
	 * Inode number of the directory which contains this subvolume.
	 * Zero for top-level subvolume or a deleted subvolume
	 */
	__u64 dirid;

	/* Latest transaction id of this subvolume */
	__u64 generation;

	/* Flags of this subvolume */
	__u64 flags;

	/* UUID of this subvolume */
	__u8[BTRFS_UUID_SIZE] uuid;

	/*
	 * UUID of the subvolume of which this subvolume is a snapshot.
	 * All zero for a non-snapshot subvolume.
	 */
	__u8[BTRFS_UUID_SIZE] parent_uuid;

	/*
	 * UUID of the subvolume from which this subvolume was received.
	 * All zero for non-received subvolume.
	 */
	__u8[BTRFS_UUID_SIZE] received_uuid;

	/* Transaction id indicating when change/create/send/receive happened */
	__u64 ctransid;
	__u64 otransid;
	__u64 stransid;
	__u64 rtransid;
	/* Time corresponding to c/o/s/rtransid */
	btrfs_ioctl_timespec ctime;
	btrfs_ioctl_timespec otime;
	btrfs_ioctl_timespec stime;
	btrfs_ioctl_timespec rtime;

	/* Must be zero */
	__u64[8] reserved;
}

enum BTRFS_MAX_ROOTREF_BUFFER_NUM			= 255;
struct btrfs_ioctl_get_subvol_rootref_args {
	/* in/out, minimum id of rootref's treeid to be searched */
	__u64 min_treeid;

	/* out */
	struct _rootref {
		__u64 treeid;
		__u64 dirid;
	} _rootref[BTRFS_MAX_ROOTREF_BUFFER_NUM] rootref;

	/* out, number of found items */
	__u8 num_items;
	__u8[7] align_;
}
// static assert((btrfs_ioctl_get_subvol_rootref_args).sizeof == 4096);

/* Error codes as returned by the kernel */
enum btrfs_err_code {
	notused,
	BTRFS_ERROR_DEV_RAID1_MIN_NOT_MET,
	BTRFS_ERROR_DEV_RAID10_MIN_NOT_MET,
	BTRFS_ERROR_DEV_RAID5_MIN_NOT_MET,
	BTRFS_ERROR_DEV_RAID6_MIN_NOT_MET,
	BTRFS_ERROR_DEV_TGT_REPLACE,
	BTRFS_ERROR_DEV_MISSING_NOT_FOUND,
	BTRFS_ERROR_DEV_ONLY_WRITABLE,
	BTRFS_ERROR_DEV_EXCL_RUN_IN_PROGRESS,
	BTRFS_ERROR_DEV_RAID1C3_MIN_NOT_MET,
	BTRFS_ERROR_DEV_RAID1C4_MIN_NOT_MET,
}

/* An error code to error string mapping for the kernel
*  error codes
*/
const(char)* btrfs_err_str()(btrfs_err_code err_code)
{
	switch (err_code) {
		case btrfs_err_code.BTRFS_ERROR_DEV_RAID1_MIN_NOT_MET:
			return "unable to go below two devices on raid1";
		case btrfs_err_code.BTRFS_ERROR_DEV_RAID1C3_MIN_NOT_MET:
			return "unable to go below three devices on raid1c3";
		case btrfs_err_code.BTRFS_ERROR_DEV_RAID1C4_MIN_NOT_MET:
			return "unable to go below four devices on raid1c4";
		case btrfs_err_code.BTRFS_ERROR_DEV_RAID10_MIN_NOT_MET:
			return "unable to go below four devices on raid10";
		case btrfs_err_code.BTRFS_ERROR_DEV_RAID5_MIN_NOT_MET:
			return "unable to go below two devices on raid5";
		case btrfs_err_code.BTRFS_ERROR_DEV_RAID6_MIN_NOT_MET:
			return "unable to go below three devices on raid6";
		case btrfs_err_code.BTRFS_ERROR_DEV_TGT_REPLACE:
			return "unable to remove the dev_replace target dev";
		case btrfs_err_code.BTRFS_ERROR_DEV_MISSING_NOT_FOUND:
			return "no missing devices found to remove";
		case btrfs_err_code.BTRFS_ERROR_DEV_ONLY_WRITABLE:
			return "unable to remove the only writeable device";
		case btrfs_err_code.BTRFS_ERROR_DEV_EXCL_RUN_IN_PROGRESS:
			return "add/delete/balance/replace/resize operation " ~
				"in progress";
		default:
			return null;
	}
}

enum BTRFS_IOC_SNAP_CREATE = _IOW!(btrfs_ioctl_vol_args)(BTRFS_IOCTL_MAGIC, 1);
enum BTRFS_IOC_DEFRAG = _IOW!(btrfs_ioctl_vol_args)(BTRFS_IOCTL_MAGIC, 2);
enum BTRFS_IOC_RESIZE = _IOW!(btrfs_ioctl_vol_args)(BTRFS_IOCTL_MAGIC, 3);
enum BTRFS_IOC_SCAN_DEV = _IOW!(btrfs_ioctl_vol_args)(BTRFS_IOCTL_MAGIC, 4);
enum BTRFS_IOC_FORGET_DEV = _IOW!(btrfs_ioctl_vol_args)(BTRFS_IOCTL_MAGIC, 5);
/* trans start and trans end are dangerous, and only for
 * use by applications that know how to avoid the
 * resulting deadlocks
 */
enum BTRFS_IOC_TRANS_START  = _IO(BTRFS_IOCTL_MAGIC, 6);
enum BTRFS_IOC_TRANS_END    = _IO(BTRFS_IOCTL_MAGIC, 7);
enum BTRFS_IOC_SYNC         = _IO(BTRFS_IOCTL_MAGIC, 8);

enum BTRFS_IOC_CLONE        = _IOW!(int)(BTRFS_IOCTL_MAGIC, 9);
enum BTRFS_IOC_ADD_DEV = _IOW!(btrfs_ioctl_vol_args)(BTRFS_IOCTL_MAGIC, 10);
enum BTRFS_IOC_RM_DEV = _IOW!(btrfs_ioctl_vol_args)(BTRFS_IOCTL_MAGIC, 11);
enum BTRFS_IOC_BALANCE = _IOW!(btrfs_ioctl_vol_args)(BTRFS_IOCTL_MAGIC, 12);

enum BTRFS_IOC_CLONE_RANGE = _IOW!(btrfs_ioctl_clone_range_args)(BTRFS_IOCTL_MAGIC, 13);

enum BTRFS_IOC_SUBVOL_CREATE = _IOW!(btrfs_ioctl_vol_args)(BTRFS_IOCTL_MAGIC, 14);
enum BTRFS_IOC_SNAP_DESTROY = _IOW!(btrfs_ioctl_vol_args)(BTRFS_IOCTL_MAGIC, 15);
enum BTRFS_IOC_DEFRAG_RANGE = _IOW!(btrfs_ioctl_defrag_range_args)(BTRFS_IOCTL_MAGIC, 16);
enum BTRFS_IOC_TREE_SEARCH = _IOWR!(btrfs_ioctl_search_args)(BTRFS_IOCTL_MAGIC, 17);
enum BTRFS_IOC_TREE_SEARCH_V2 = _IOWR!(btrfs_ioctl_search_args_v2)(BTRFS_IOCTL_MAGIC, 17);
enum BTRFS_IOC_INO_LOOKUP = _IOWR!(btrfs_ioctl_ino_lookup_args)(BTRFS_IOCTL_MAGIC, 18);
enum BTRFS_IOC_DEFAULT_SUBVOL = _IOW!(__u64)(BTRFS_IOCTL_MAGIC, 19);
enum BTRFS_IOC_SPACE_INFO = _IOWR!(btrfs_ioctl_space_args)(BTRFS_IOCTL_MAGIC, 20);
enum BTRFS_IOC_START_SYNC = _IOR!(__u64)(BTRFS_IOCTL_MAGIC, 24);
enum BTRFS_IOC_WAIT_SYNC  = _IOW!(__u64)(BTRFS_IOCTL_MAGIC, 22);
enum BTRFS_IOC_SNAP_CREATE_V2 = _IOW!(btrfs_ioctl_vol_args_v2)(BTRFS_IOCTL_MAGIC, 23);
enum BTRFS_IOC_SUBVOL_CREATE_V2 = _IOW!(btrfs_ioctl_vol_args_v2)(BTRFS_IOCTL_MAGIC, 24);
enum BTRFS_IOC_SUBVOL_GETFLAGS = _IOR!(__u64)(BTRFS_IOCTL_MAGIC, 25);
enum BTRFS_IOC_SUBVOL_SETFLAGS = _IOW!(__u64)(BTRFS_IOCTL_MAGIC, 26);
enum BTRFS_IOC_SCRUB = _IOWR!(btrfs_ioctl_scrub_args)(BTRFS_IOCTL_MAGIC, 27);
enum BTRFS_IOC_SCRUB_CANCEL = _IO(BTRFS_IOCTL_MAGIC, 28);
enum BTRFS_IOC_SCRUB_PROGRESS = _IOWR!(btrfs_ioctl_scrub_args)(BTRFS_IOCTL_MAGIC, 29);
enum BTRFS_IOC_DEV_INFO = _IOWR!(btrfs_ioctl_dev_info_args)(BTRFS_IOCTL_MAGIC, 30);
enum BTRFS_IOC_FS_INFO = _IOR!(btrfs_ioctl_fs_info_args)(BTRFS_IOCTL_MAGIC, 31);
enum BTRFS_IOC_BALANCE_V2 = _IOWR!(btrfs_ioctl_balance_args)(BTRFS_IOCTL_MAGIC, 32);
enum BTRFS_IOC_BALANCE_CTL = _IOW!(int)(BTRFS_IOCTL_MAGIC, 33);
enum BTRFS_IOC_BALANCE_PROGRESS = _IOR!(btrfs_ioctl_balance_args)(BTRFS_IOCTL_MAGIC, 34);
enum BTRFS_IOC_INO_PATHS = _IOWR!(btrfs_ioctl_ino_path_args)(BTRFS_IOCTL_MAGIC, 35);
enum BTRFS_IOC_LOGICAL_INO = _IOWR!(btrfs_ioctl_logical_ino_args)(BTRFS_IOCTL_MAGIC, 36);
enum BTRFS_IOC_SET_RECEIVED_SUBVOL = _IOWR!(btrfs_ioctl_received_subvol_args)(BTRFS_IOCTL_MAGIC, 37);

static if (BTRFS_IOC_SET_RECEIVED_SUBVOL_32_COMPAT_DEFINED)
enum BTRFS_IOC_SET_RECEIVED_SUBVOL_32 = _IOWR!(btrfs_ioctl_received_subvol_args_32)(BTRFS_IOCTL_MAGIC, 37);

static if (BTRFS_IOC_SEND_64_COMPAT_DEFINED)
enum BTRFS_IOC_SEND_64 = _IOW!(btrfs_ioctl_send_args_64)(BTRFS_IOCTL_MAGIC, 38);

enum BTRFS_IOC_SEND = _IOW!(btrfs_ioctl_send_args)(BTRFS_IOCTL_MAGIC, 38);
enum BTRFS_IOC_DEVICES_READY = _IOR!(btrfs_ioctl_vol_args)(BTRFS_IOCTL_MAGIC, 39);
enum BTRFS_IOC_QUOTA_CTL = _IOWR!(btrfs_ioctl_quota_ctl_args)(BTRFS_IOCTL_MAGIC, 40);
enum BTRFS_IOC_QGROUP_ASSIGN = _IOW!(btrfs_ioctl_qgroup_assign_args)(BTRFS_IOCTL_MAGIC, 41);
enum BTRFS_IOC_QGROUP_CREATE = _IOW!(btrfs_ioctl_qgroup_create_args)(BTRFS_IOCTL_MAGIC, 42);
enum BTRFS_IOC_QGROUP_LIMIT = _IOR!(btrfs_ioctl_qgroup_limit_args)(BTRFS_IOCTL_MAGIC, 43);
enum BTRFS_IOC_QUOTA_RESCAN = _IOW!(btrfs_ioctl_quota_rescan_args)(BTRFS_IOCTL_MAGIC, 44);
enum BTRFS_IOC_QUOTA_RESCAN_STATUS = _IOR!(btrfs_ioctl_quota_rescan_args)(BTRFS_IOCTL_MAGIC, 45);
enum BTRFS_IOC_QUOTA_RESCAN_WAIT = _IO(BTRFS_IOCTL_MAGIC, 46);
enum BTRFS_IOC_GET_FSLABEL = _IOR!(char[BTRFS_LABEL_SIZE])(BTRFS_IOCTL_MAGIC, 49);
enum BTRFS_IOC_SET_FSLABEL = _IOW!(char[BTRFS_LABEL_SIZE])(BTRFS_IOCTL_MAGIC, 50);
enum BTRFS_IOC_GET_DEV_STATS = _IOWR!(btrfs_ioctl_get_dev_stats)(BTRFS_IOCTL_MAGIC, 52);
enum BTRFS_IOC_DEV_REPLACE = _IOWR!(btrfs_ioctl_dev_replace_args)(BTRFS_IOCTL_MAGIC, 53);
enum BTRFS_IOC_FILE_EXTENT_SAME = _IOWR!(btrfs_ioctl_same_args)(BTRFS_IOCTL_MAGIC, 54);
enum BTRFS_IOC_GET_FEATURES = _IOR!(btrfs_ioctl_feature_flags)(BTRFS_IOCTL_MAGIC, 57);
enum BTRFS_IOC_SET_FEATURES = _IOW!(btrfs_ioctl_feature_flags[2])(BTRFS_IOCTL_MAGIC, 57);
enum BTRFS_IOC_GET_SUPPORTED_FEATURES = _IOR!(btrfs_ioctl_feature_flags[3])(BTRFS_IOCTL_MAGIC, 57);
enum BTRFS_IOC_RM_DEV_V2	= _IOW!(btrfs_ioctl_vol_args_v2)(BTRFS_IOCTL_MAGIC, 58);
enum BTRFS_IOC_LOGICAL_INO_V2 = _IOWR!(btrfs_ioctl_logical_ino_args)(BTRFS_IOCTL_MAGIC, 59);
enum BTRFS_IOC_GET_SUBVOL_INFO = _IOR!(btrfs_ioctl_get_subvol_info_args)(BTRFS_IOCTL_MAGIC, 60);
enum BTRFS_IOC_GET_SUBVOL_ROOTREF = _IOWR!(btrfs_ioctl_get_subvol_rootref_args)(BTRFS_IOCTL_MAGIC, 61);
enum BTRFS_IOC_INO_LOOKUP_USER = _IOWR!(btrfs_ioctl_ino_lookup_user_args)(BTRFS_IOCTL_MAGIC, 62);
enum BTRFS_IOC_SNAP_DESTROY_V2 = _IOW!(btrfs_ioctl_vol_args_v2)(BTRFS_IOCTL_MAGIC, 63);
