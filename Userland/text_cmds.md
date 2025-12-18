# Building text_cmds for ARM64

text_cmds contains essential text processing utilities for Darwin/macOS.

## Overview

text_cmds provides text manipulation utilities including:

- `cat` - Concatenate and display files
- `head` - Display first lines
- `tail` - Display last lines
- `wc` - Word, line, character count
- `cut` - Cut out fields
- `paste` - Merge lines
- `join` - Join files on common field
- `sort` - Sort lines
- `uniq` - Report/filter repeated lines
- `comm` - Compare sorted files
- `diff` / `diff3` - Compare files
- `cmp` - Compare files byte by byte
- `tr` - Translate characters
- `fold` - Fold long lines
- `fmt` - Format text
- `col` - Filter reverse line feeds
- `colrm` - Remove columns
- `column` - Format into columns
- `expand` / `unexpand` - Tab conversion
- `nl` - Number lines
- `pr` - Paginate for printing
- `rev` - Reverse lines
- `rs` - Reshape arrays
- `split` - Split files
- `csplit` - Context split
- `md5` - MD5 checksum

## Source

Download from Apple Open Source:
- **URL**: https://opensource.apple.com/source/text_cmds/
- **Recommended Version**: text_cmds-118 or latest

```bash
curl -O https://opensource.apple.com/tarballs/text_cmds/text_cmds-118.tar.gz
tar xzf text_cmds-118.tar.gz
cd text_cmds-118
```

## Dependencies

| Dependency | Purpose | Required |
|------------|---------|----------|
| [Libc](Libc.md) | C standard library | ✅ Yes |
| XNU Headers | System calls | ✅ Yes |

## Build Instructions

### Using Xcode

```bash
xcodebuild -project text_cmds.xcodeproj \
    -alltargets \
    -configuration Release \
    ARCHS=arm64 \
    SDKROOT=macosx \
    DSTROOT=/path/to/install
```

### Manual Build

```bash
export CC=clang
export CFLAGS="-arch arm64 -isysroot $(xcrun --sdk macosx --show-sdk-path) -O2"

# Simple single-file commands
clang ${CFLAGS} -o cat cat/cat.c
clang ${CFLAGS} -o head head/head.c
clang ${CFLAGS} -o tail tail/tail.c
clang ${CFLAGS} -o wc wc/wc.c
clang ${CFLAGS} -o cut cut/cut.c
clang ${CFLAGS} -o sort sort/sort.c
clang ${CFLAGS} -o uniq uniq/uniq.c
clang ${CFLAGS} -o tr tr/tr.c
```

## Key Commands

### cat - Concatenate Files

```bash
cat file.txt              # Display file
cat file1.txt file2.txt   # Concatenate files
cat -n file.txt           # Number lines
cat -b file.txt           # Number non-blank lines
```

### head / tail

```bash
head -20 file.txt         # First 20 lines
tail -20 file.txt         # Last 20 lines
tail -f logfile           # Follow file (live updates)
```

### sort / uniq

```bash
sort file.txt             # Sort lines
sort -n file.txt          # Numeric sort
sort -r file.txt          # Reverse sort
sort file.txt | uniq      # Remove duplicates
sort file.txt | uniq -c   # Count duplicates
```

### wc - Word Count

```bash
wc file.txt               # Lines, words, characters
wc -l file.txt            # Lines only
wc -w file.txt            # Words only
wc -c file.txt            # Characters only
```

### cut / paste

```bash
cut -d: -f1 /etc/passwd   # Cut first field (delimiter :)
cut -c1-10 file.txt       # Cut first 10 characters
paste file1 file2         # Merge files side by side
```

## Output Binaries

| Binary | Location | Description |
|--------|----------|-------------|
| `cat` | `/bin/` | Concatenate files |
| `head`, `tail` | `/usr/bin/` | Display file parts |
| `sort`, `uniq` | `/usr/bin/` | Sort and filter |
| `wc` | `/usr/bin/` | Count words/lines |
| `cut`, `paste` | `/usr/bin/` | Field manipulation |
| `diff` | `/usr/bin/` | Compare files |
| `tr` | `/usr/bin/` | Translate characters |

## References

- [Apple Open Source - text_cmds](https://opensource.apple.com/source/text_cmds/)
- [POSIX text utilities](https://pubs.opengroup.org/onlinepubs/9699919799/)
