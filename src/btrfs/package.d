module btrfs;

import core.stdc.errno;
import core.sys.posix.sys.ioctl;
import core.sys.posix.sys.stat;
import core.sys.posix.sys.types;

import std.algorithm.comparison;
import std.exception;
import std.math;
import std.string;

import ae.utils.bitmanip;
import ae.utils.math : eq;

import btrfs.c.ioctl;
import btrfs.c.kerncompat;
import btrfs.c.kernel_shared.ctree;
import btrfs.c.kernel_lib.sizes;

private
{
	alias __fsword_t = uint;
	struct fsid_t { int[2] __val; }
	struct statfs_t
	{
		__fsword_t f_type;
		__fsword_t f_bsize;
		fsblkcnt_t f_blocks;
		fsblkcnt_t f_bfree;
		fsblkcnt_t f_bavail;
		fsfilcnt_t f_files;
		fsfilcnt_t f_ffree;
		fsid_t     f_fsid;
		__fsword_t f_namelen;
		__fsword_t f_frsize;
		__fsword_t f_flags;
		__fsword_t[5] f_spare;
		ubyte[4096 - 88] __unknown; // D - seems to vary A LOT across platforms / libcs
	}
	extern(C) int fstatfs(int fd, statfs_t* buf);
}

enum BTRFS_SUPER_MAGIC = 0x9123683E;

/// Returns true is fd is on a btrfs filesystem.
bool isBTRFS(int fd)
{
	statfs_t sfs;
	fstatfs(fd, &sfs).eq(0).errnoEnforce("fstatfs");
	return sfs.f_type == BTRFS_SUPER_MAGIC;
}

/// Returns true is fd is the root of a btrfs subvolume.
bool isSubvolume(int fd)
{
	stat_t st;
	fstat(fd, &st).eq(0).errnoEnforce("fstat");
	return st.st_ino == BTRFS_FIRST_FREE_OBJECTID;
}

/// Returns the subvolume ID containing the file open in fd.
u64 getSubvolumeID(int fd)
{
	btrfs_ioctl_ino_lookup_args args;
	args.treeid = 0;
	args.objectid = BTRFS_FIRST_FREE_OBJECTID;
	ioctl(fd, BTRFS_IOC_INO_LOOKUP, &args).eq(0).errnoEnforce("ino lookup");
	return args.treeid;
}

enum __u64[2] treeSearchAllObjectIDs = [0, -1];
enum __u64[2] treeSearchAllOffsets   = [0, -1];
enum __u64[2] treeSearchAllTransIDs  = [0, -1];

/// Raw tree search
void treeSearch(
	/// Handle to the filesystem
	int fd,
	/// Tree to search in
	__u64 treeID,
	/// Min and max (inclusive) object IDs to search
	__u64[2] objectIDs,
	/// Min and max (inclusive) types to search
	__u8[2] types,
	/// Min and max (inclusive) offsets to search
	__u64[2] offsets,
	/// Min and max (inclusive) transaction IDs to search
	__u64[2] transIDs,
	/// Callback receiving the search results
	scope void delegate(
		/// Search result header, containing the object and transaction ID, offset and type
		const ref btrfs_ioctl_search_header header,
		/// Raw data - must be cast to the correct type
		const void[] data,
	) callback,
)
{
	// Lexicographic ordering for tree search
	static union Key
	{
		struct Fields
		{
		align(1):
			BigEndian!__u64 objectID;
			BigEndian!__u8  type;
			BigEndian!__u64 offset;
		}
		static assert(Fields.sizeof == 0x11);

		Fields fields;
		ubyte[Fields.sizeof] bytes;

		this(__u64 objectID, __u8 type, __u64 offset)
		{
			fields = Fields(
				BigEndian!__u64(objectID),
				BigEndian!__u8 (type),
				BigEndian!__u64(offset),
			);
		}

		void opUnary(string op : "++")()
		{
			foreach_reverse (ref b; bytes)
				if (++b != 0)
					return; // No overflow (otherwise, continue to carry the 1)
			assert(false, "Search key overflow");
		}

		bool opBinary(string op)(const ref Key o) const
		if (is(typeof(mixin(`0` ~ op ~ `0`)) == bool))
		{
			return mixin(`bytes` ~ op ~ `o.bytes`);
		}

		int opCmp(const ref Key o) const
		{
			return cmp(bytes[], o.bytes[]);
		}
	}

	Key min = Key(objectIDs[0], types[0], offsets[0]);
	Key max = Key(objectIDs[1], types[1], offsets[1]);

	btrfs_ioctl_search_args args;
	btrfs_ioctl_search_key* sk = &args.key;

	sk.tree_id = treeID;
	sk.max_objectid = max.fields.objectID;
	sk.max_type     = max.fields.type;
	sk.max_offset   = max.fields.offset;
	sk.min_transid  = transIDs[0];
	sk.max_transid  = transIDs[1];
	sk.nr_items = 4096;

	do
	{
		sk.min_objectid = min.fields.objectID;
		sk.min_type     = min.fields.type    ;
		sk.min_offset   = min.fields.offset  ;
		ioctl(fd, BTRFS_IOC_TREE_SEARCH, &args).eq(0).errnoEnforce("tree search");

		if (sk.nr_items == 0)
			break;

		ulong off = 0;
		btrfs_ioctl_search_header* sh;
		foreach (i; 0 .. sk.nr_items)
		{
			sh = cast(btrfs_ioctl_search_header *)(args.buf.ptr + off);
			off += (*sh).sizeof;
			auto data = (args.buf.ptr + off)[0 .. sh.len];
			off += sh.len;

			if (
				objectIDs[0] <= sh.objectid && sh.objectid <= objectIDs[1] &&
				types    [0] <= sh.type     && sh.type     <= types    [1] &&
				offsets  [0] <= sh.offset   && sh.offset   <= offsets  [1] &&
				transIDs [0] <= sh.transid  && sh.transid  <= transIDs [1]
			)
				callback(*sh, data);
		}

		assert(sh.type < 256);
		min.fields.objectID = sh.objectid;
		min.fields.type     = cast(__u8)sh.type;
		min.fields.offset   = sh.offset;
		min++;
	}
	while (min <= max);
}

/// Typed tree search
void treeSearch(
	/// BTRFS type identifier to search for
	__u8 btrfsType,
	/// Structure type describing the data
	Type,
)(
	/// Handle to the filesystem
	int fd,
	/// Tree to search in
	__u64 treeID,
	/// Min and max (inclusive) object IDs to search
	__u64[2] objectIDs,
	/// Min and max (inclusive) offsets to search
	__u64[2] offsets,
	/// Min and max (inclusive) transaction IDs to search
	__u64[2] transIDs,
	/// Callback receiving the search results
	scope void delegate(
		/// Search result header, containing the object and transaction ID, and offset
		const ref btrfs_ioctl_search_header header,
		/// Search result data
		/// For variable-length structures, additional data can be
		/// accessed by reading past the end of this variable.
		/// `header.len` indicates the real total size of the data.
		const ref Type data,
	) callback,
)
{
	__u8[2] types = [btrfsType, btrfsType];
	treeSearch(
		fd, treeID, objectIDs, types, offsets, transIDs,
		(const ref btrfs_ioctl_search_header header, const void[] data)
		{
			callback(header, *cast(Type*)data.ptr);
		}
	);
}

/// Enumerate all chunks in the filesystem.
void enumerateChunks(
	/// Handle to the filesystem
	int fd,
	/// Result callback
	scope void delegate(
		/// Chunk logical address
		u64 offset,
		/// Chunk info
		/// Stripes can be indexed according to num_stripes
		const ref btrfs_chunk chunk,
	) callback,
)
{
	treeSearch!(
		BTRFS_CHUNK_ITEM_KEY,
		btrfs_chunk,
	)(
		fd,
		BTRFS_CHUNK_TREE_OBJECTID,
		treeSearchAllObjectIDs,
		treeSearchAllOffsets,
		treeSearchAllTransIDs,
		(const ref btrfs_ioctl_search_header header, const ref btrfs_chunk chunk)
		{
			callback(header.offset, chunk);
		}
	);
}

private ubyte[SZ_64K] logicalInoBuf;

/// Get inode at this logical offset
void logicalIno(
	/// File descriptor to the root (subvolume) containing the inode
	int fd,
	/// Logical offset to resolve
	u64 logical,
	/// Result callback
	scope void delegate(
		/// The inode
		u64 inode,
		/// The offset within the inode file
		/// Will be zero if `ignoreOffset` is true
		u64 offset,
		/// The filesystem root ID containing the inode
		u64 root,
	) callback,
	/// Ignore the offset when querying extent ownership
	/// If this particular offset is not in use by any file but the extent is,
	/// this allows querying which file is pinning the offset.
	bool ignoreOffset = false,
	/// Query buffer
	ubyte[] buf = logicalInoBuf[],
)
{
	u64 flags = 0;
	if (ignoreOffset)
		flags |= BTRFS_LOGICAL_INO_ARGS_IGNORE_OFFSET;

	assert(buf.length > btrfs_data_container.sizeof);
	auto inodes = cast(btrfs_data_container*)buf.ptr;

	ulong request = BTRFS_IOC_LOGICAL_INO;
	if (buf.length > SZ_64K || flags != 0)
		request = BTRFS_IOC_LOGICAL_INO_V2;

	btrfs_ioctl_logical_ino_args loi;
	loi.logical = logical;
	loi.size = buf.length;
	loi.flags = flags;
	loi.inodes = cast(__u64)inodes;

	ioctl(fd, request, &loi).eq(0).errnoEnforce("logical ino");
	for (auto i = 0; i < inodes.elem_cnt; i += 3)
	{
		u64 inum   = inodes.val.ptr[i];
		u64 offset = inodes.val.ptr[i+1];
		u64 root   = inodes.val.ptr[i+2];

		callback(inum, offset, root);
	}
}

/// Obtain all paths for an inode.
void inoPaths(
	/// Handle to the filesystem
	int fd,
	/// The inode
	u64 inode,
	/// Callback for receiving file names
	scope void delegate(char[] fn) callback,
)
{
	union Buf
	{
		btrfs_data_container container;
		ubyte[0x10000] buf;
	}
	Buf fspath;

	btrfs_ioctl_ino_path_args ipa;
	ipa.inum = inode;
	ipa.size = fspath.sizeof;
	ipa.fspath = ptr_to_u64(&fspath);

	ioctl(fd, BTRFS_IOC_INO_PATHS, &ipa).eq(0).errnoEnforce("ino paths");

	foreach (i; 0 .. fspath.container.elem_cnt)
	{
		auto ptr = fspath.buf.ptr;
		ptr += fspath.container.val.offsetof;
		ptr += fspath.container.val.ptr[i];
		auto str = cast(char *)ptr;
		callback(fromStringz(str));
	}
}

/// Obtains the relative path of a given filesystem object for the given filesystem root.
void inoLookup(
	/// Handle to the filesystem
	int fd,
	/// Tree ID containing the filesystem object
	u64 treeID,
	/// Filesystem object
	u64 objectID,
	/// Callback receiving the relative path (it ends with /)
	scope void delegate(char[] fn) callback,
)
{
	btrfs_ioctl_ino_lookup_args args;
	args.treeid = treeID;
	args.objectid = objectID;

	ioctl(fd, BTRFS_IOC_INO_LOOKUP, &args).eq(0).errnoEnforce("ino lookup");
	args.name[$-1] = 0;
	callback(fromStringz(args.name.ptr));
}

/// Find a root's parent root, and where it is within it
void findRootBackRef(
	/// Handle to the filesystem
	int fd,
	/// The child root ID whose parent to find
	__u64 rootID,
	/// Result callback
	scope void delegate(
		/// The parent root ID
		__u64 parentRootID,
		/// The directory ID (within the parent root) containing the child
		__u64 dirID,
		/// The sequence of the child entry within the directory
		__u64 sequence,
		/// The base file name of the child within the directory
		char[] name,
	) callback,
)
{
	treeSearch!(
		BTRFS_ROOT_BACKREF_KEY,
		btrfs_root_ref,
	)(
		fd,
		BTRFS_ROOT_TREE_OBJECTID,
		[rootID, rootID],
		treeSearchAllOffsets,
		treeSearchAllTransIDs,
		(const ref btrfs_ioctl_search_header header, const ref btrfs_root_ref data)
		{
			auto parentRoot = header.offset;
			auto name = (cast(char*)(&data + 1))[0 .. data.name_len];
			callback(parentRoot, data.dirid, data.sequence, name);
		}
	);
}

/// Clone a file range
void cloneRange(
	/// Source file descriptor
	int srcFile,
	/// Offset in source file to clone from
	ulong srcOffset,
	/// Target file descriptor
	int dstFile,
	/// Offset in target file to clone over
	ulong dstOffset,
	/// Number of bytes to clone
	ulong length,
)
{
	btrfs_ioctl_clone_range_args args;

	args.src_fd = srcFile;
	args.src_offset = srcOffset;
	args.src_length = length;
	args.dest_offset = dstOffset;

	int ret = ioctl(dstFile, BTRFS_IOC_CLONE_RANGE, &args);
	errnoEnforce(ret >= 0, "ioctl(BTRFS_IOC_CLONE_RANGE)");
}

version (btrfsUnittest)
unittest
{
	if (!checkBtrfs())
		return;
	import std.range, std.random, std.algorithm, std.file;
	import std.stdio : File;
	enum blockSize = 16*1024; // TODO: detect
	auto data = blockSize.iota.map!(n => uniform!ubyte).array();
	std.file.write("test1.bin", data);
	scope(exit) remove("test1.bin");
	auto f1 = File("test1.bin", "rb");
	scope(exit) remove("test2.bin");
	auto f2 = File("test2.bin", "wb");
	cloneRange(f1.fileno, 0, f2.fileno, 0, blockSize);
	f2.close();
	f1.close();
	assert(std.file.read("test2.bin") == data);
}

struct Extent
{
	int fd;
	ulong offset;
}

struct SameExtentResult
{
	ulong totalBytesDeduped;
}

SameExtentResult sameExtent(in Extent[] extents, ulong length)
{
	assert(extents.length >= 2, "Need at least 2 extents to deduplicate");

	auto buf = new ubyte[
		      btrfs_ioctl_same_args.sizeof +
		      btrfs_ioctl_same_extent_info.sizeof * extents.length];
	auto same = cast(btrfs_ioctl_same_args*) buf.ptr;

	same.length = length;
	same.logical_offset = extents[0].offset;
	enforce(extents.length < ushort.max, "Too many extents");
	same.dest_count = cast(ushort)(extents.length - 1);

	foreach (i, ref extent; extents[1..$])
	{
		same.info.ptr[i].fd = extent.fd;
		same.info.ptr[i].logical_offset = extent.offset;
		same.info.ptr[i].status = -1;
	}

	int ret = ioctl(extents[0].fd, BTRFS_IOC_FILE_EXTENT_SAME, same);
	errnoEnforce(ret >= 0, "ioctl(BTRFS_IOC_FILE_EXTENT_SAME)");

	SameExtentResult result;

	foreach (i, ref extent; extents[1..$])
	{
		auto status = same.info.ptr[i].status;
		if (status)
		{
			enforce(status != BTRFS_SAME_DATA_DIFFERS,
				"Extent #%d differs".format(i+1));
			errno = -status;
			errnoEnforce(false,
				"Deduplicating extent #%d returned status %d".format(i+1, status));
		}
		result.totalBytesDeduped += same.info.ptr[i].bytes_deduped;
	}

	return result;
}

version (btrfsUnittest)
unittest
{
	if (!checkBtrfs())
		return;
	import std.range, std.random, std.algorithm, std.file;
	import std.stdio : File;
	enum blockSize = 16*1024; // TODO: detect
	auto data = blockSize.iota.map!(n => uniform!ubyte).array();
	std.file.write("test1.bin", data);
	scope(exit) remove("test1.bin");
	std.file.write("test2.bin", data);
	scope(exit) remove("test2.bin");

	{
		auto f1 = File("test1.bin", "r+b");
		auto f2 = File("test2.bin", "r+b");
		sameExtent([
			Extent(f1.fileno, 0),
			Extent(f2.fileno, 0),
		], blockSize);
	}

	{
		data[0]++;
		std.file.write("test2.bin", data);
		auto f1 = File("test1.bin", "r+b");
		auto f2 = File("test2.bin", "r+b");
		assertThrown!Exception(sameExtent([
			Extent(f1.fileno, 0),
			Extent(f2.fileno, 0),
		], blockSize));
	}
}

version (btrfsUnittest)
{
	import ae.sys.file;
	import std.stdio : stderr;

	bool checkBtrfs(string moduleName = __MODULE__)()
	{
		auto fs = getPathFilesystem(".");
		if (fs != "btrfs")
		{
			stderr.writefln("Current filesystem is %s, not btrfs, skipping %s test.", fs, moduleName);
			return false;
		}
		return true;
	}
}
