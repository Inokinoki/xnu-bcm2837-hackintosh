/* lzfse-dec IN OUT: decompress a raw LZFSE ("bvx2") stream; built in the pi-ios-root container
 * against the lzfse sources that apfs-fuse vendors (see tools/im4p-extract.py). */
#include <stdio.h>
#include <stdlib.h>
#include "lzfse.h"

int main(int argc, char **argv)
{
	if (argc != 3) { fprintf(stderr, "usage: %s IN OUT\n", argv[0]); return 2; }
	FILE *f = fopen(argv[1], "rb");
	if (!f) { perror(argv[1]); return 1; }
	fseek(f, 0, SEEK_END); long n = ftell(f); fseek(f, 0, SEEK_SET);
	unsigned char *in = malloc(n);
	if (fread(in, 1, n, f) != (size_t)n) return 1;
	fclose(f);
	size_t cap = 64u << 20;
	unsigned char *out = malloc(cap);
	size_t m = lzfse_decode_buffer(out, cap, in, n, NULL);
	if (m == 0 || m == cap) { fprintf(stderr, "lzfse decode failed\n"); return 1; }
	f = fopen(argv[2], "wb");
	fwrite(out, 1, m, f);
	fclose(f);
	return 0;
}
