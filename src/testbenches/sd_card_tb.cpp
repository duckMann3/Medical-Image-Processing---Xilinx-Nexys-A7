#include <cstdint>
#include <cstdio>
#include <vector>
#include <unordered_map>
#include <string>
#include <cstring>

// -----------------------------------------------------------------------------
// FatFs Environment Simulation:
// Run Using g++ compiler
// -----------------------------------------------------------------------------

// Integer Type typedefs
typedef uint8_t  u8;
typedef uint32_t u32;
typedef uint32_t UINT;
typedef int      FRESULT;

// Image Specification
#define IMG_WIDTH        640
#define IMG_HEIGHT       480
#define BYTES_PER_PIXEL  2
#define IMAGE_SIZE       (IMG_WIDTH * IMG_HEIGHT * BYTES_PER_PIXEL)

// Status codes
#define XST_SUCCESS 0
#define XST_FAILURE 1

// xil_printf replacement (stdout)
#define xil_printf(fmt, ...) std::printf(fmt, ##__VA_ARGS__)

#define FR_OK       0
#define FR_DISK_ERR 1
#define FR_NO_FILE  2
#define FR_INT_ERR  3


// For the test, it's just a dummy placeholder...
struct FATFS {};

struct FIL {
    std::string name;  // file name in our simulated SD
    size_t pos;        // current read position
};

// Simulated SD card: filename -> file contents
static std::unordered_map<std::string, std::vector<u8>> g_files;

// Error flags
static bool g_mount_should_fail = false;
static bool g_read_should_fail  = false;

FATFS fatfs;

// f_mount: simulate SD card mount success/failure
FRESULT f_mount(FATFS* fs, const char* path, u8 opt) {
    (void)fs;
    (void)path;
    (void)opt;
    return g_mount_should_fail ? FR_DISK_ERR : FR_OK;
}

// f_open: look up file in map
FRESULT f_open(FIL* fp, const char* path, u8 mode) {
    (void)mode;
    auto it = g_files.find(path);
    if (it == g_files.end()) {
        return FR_NO_FILE;
    }
    fp->name = path;
    fp->pos  = 0;
    return FR_OK;
}

// f_read: copy bytes from our in-memory file into dst
FRESULT f_read(FIL* fp, void* dst, UINT bytes_to_read, UINT* br) {
    auto it = g_files.find(fp->name);
    if (it == g_files.end()) {
        *br = 0;
        return FR_INT_ERR;
    }

    if (g_read_should_fail) {
        *br = 0;
        return FR_INT_ERR;
    }

    const std::vector<u8>& data = it->second;

    size_t remaining = data.size() - fp->pos;
    size_t n = (bytes_to_read < remaining) ? bytes_to_read : remaining;

    std::memcpy(dst, data.data() + fp->pos, n);
    fp->pos += n;
    *br = static_cast<UINT>(n);

    return FR_OK;
}

// f_close: no-op
FRESULT f_close(FIL* fp) {
    (void)fp;
    return FR_OK;
}

// Global image buffer (same as your code)
u8 image_buffer[IMAGE_SIZE];

// sd_mount: identical logic to your original, using mocked f_mount
int sd_mount(void) {
    FRESULT res;

    xil_printf("Mounting the SD card..\r\n");
    res = f_mount(&fatfs, "0:/", 0);
    if (res != FR_OK) {
        xil_printf("f_mount failed: %d\r\n", res);
        return XST_FAILURE;
    }

    xil_printf("SD card mounted.\r\n");
    return XST_SUCCESS;
}

// sd_load_file: identical logic to your original, using mocked f_* calls
int sd_load_file(const char* name, u8* dst, u32 max_bytes) {
    FIL file;
    FRESULT res;
    UINT br;

    xil_printf("Opening %s...\r\n", name);
    res = f_open(&file, name, /*FA_READ*/ 0);
    if (res != FR_OK) {
        xil_printf("f_open failed: %d\r\n", res);
        return XST_FAILURE;
    }

    res = f_read(&file, dst, max_bytes, &br);
    f_close(&file);

    if (res != FR_OK) {
        xil_printf("f_open failed: %d\r\n", res);
        return XST_FAILURE;
    }

    xil_printf("Read %u bytes from %s\r\n", br, name);
    return XST_SUCCESS;
}

// Test framework helpers
struct TestContext {
    int passed = 0;
    int failed = 0;

    void check(bool cond, const char* name) {
        if (cond) {
            ++passed;
            std::printf("[PASS] %s\n", name);
        } else {
            ++failed;
            std::printf("[FAIL] %s\n", name);
        }
    }
};

// Reset global environment between tests
void reset_environment() {
    g_files.clear();
    g_mount_should_fail = false;
    g_read_should_fail  = false;

    std::memset(image_buffer, 0xAA, sizeof(image_buffer));
}

// Individual tests

// Mount: success 
void test_mount_success(TestContext& ctx) {
    reset_environment();
    g_mount_should_fail = false;

    int status = sd_mount();
    ctx.check(status == XST_SUCCESS, "Mount success returns XST_SUCCESS");
}

// Mount: failure 
void test_mount_failure(TestContext& ctx) {
    reset_environment();
    g_mount_should_fail = true;

    int status = sd_mount();
    ctx.check(status == XST_FAILURE, "Mount failure returns XST_FAILURE");
}

// Load file: missing file
void test_load_missing_file(TestContext& ctx) {
    reset_environment();
    g_mount_should_fail = false;

    // We don't populate g_files["missing.raw"], so f_open should fail
    int status = sd_load_file("missing.raw", image_buffer, IMAGE_SIZE);
    ctx.check(status == XST_FAILURE, "Load missing file returns XST_FAILURE");

    // Ensure buffer was not modified (still sentinel 0xAA)
    bool untouched = true;
    for (size_t i = 0; i < IMAGE_SIZE; ++i) {
        if (image_buffer[i] != 0xAA) {
            untouched = false;
            break;
        }
    }
    ctx.check(untouched, "Buffer unchanged when file open fails");
}

// Load file: exact-size file, full buffer filled
void test_load_exact_size(TestContext& ctx) {
    reset_environment();
    g_mount_should_fail = false;

    // Create a "golden" file exactly IMAGE_SIZE bytes, with a simple pattern
    std::vector<u8> golden(IMAGE_SIZE);
    for (size_t i = 0; i < golden.size(); ++i) {
        golden[i] = static_cast<u8>(i & 0xFF);
    }
    g_files["img0.raw"] = golden;

    int status = sd_load_file("img0.raw", image_buffer, IMAGE_SIZE);
    ctx.check(status == XST_SUCCESS, "Load exact-size file returns XST_SUCCESS");

    // Verify entire buffer matches the golden data
    bool match = true;
    for (size_t i = 0; i < IMAGE_SIZE; ++i) {
        if (image_buffer[i] != golden[i]) {
            match = false;
            break;
        }
    }
    ctx.check(match, "Buffer matches file data for exact-size file");
}

// Load file: file smaller than buffer (short read)
void test_load_short_file(TestContext& ctx) {
    reset_environment();
    g_mount_should_fail = false;

    const size_t FILE_SIZE = IMAGE_SIZE / 2;

    std::vector<u8> golden(FILE_SIZE);
    for (size_t i = 0; i < golden.size(); ++i) {
        golden[i] = static_cast<u8>((i * 3) & 0xFF);
    }
    g_files["img0.raw"] = golden;

    int status = sd_load_file("img0.raw", image_buffer, IMAGE_SIZE);
    ctx.check(status == XST_SUCCESS, "Load short file returns XST_SUCCESS");

    // First FILE_SIZE bytes should match file contents
    bool head_match = true;
    for (size_t i = 0; i < FILE_SIZE; ++i) {
        if (image_buffer[i] != golden[i]) {
            head_match = false;
            break;
        }
    }
    ctx.check(head_match, "Short file: prefix of buffer matches file data");

    // Remaining bytes should still be sentinel 0xAA
    bool tail_untouched = true;
    for (size_t i = FILE_SIZE; i < IMAGE_SIZE; ++i) {
        if (image_buffer[i] != 0xAA) {
            tail_untouched = false;
            break;
        }
    }
    ctx.check(tail_untouched, "Short file: tail of buffer unchanged");
}

// Load file: file larger than buffer 
void test_load_large_file_truncated(TestContext& ctx) {
    reset_environment();
    g_mount_should_fail = false;

    const size_t FILE_SIZE = IMAGE_SIZE + 100; // bigger than buffer

    std::vector<u8> golden(FILE_SIZE);
    for (size_t i = 0; i < golden.size(); ++i) {
        golden[i] = static_cast<u8>((i * 7) & 0xFF);
    }
    g_files["img0.raw"] = golden;

    int status = sd_load_file("img0.raw", image_buffer, IMAGE_SIZE);
    ctx.check(status == XST_SUCCESS, "Load large file returns XST_SUCCESS");

    // Only first IMAGE_SIZE bytes should be copied
    bool match = true;
    for (size_t i = 0; i < IMAGE_SIZE; ++i) {
        if (image_buffer[i] != golden[i]) {
            match = false;
            break;
        }
    }
    ctx.check(match, "Large file: buffer matches first IMAGE_SIZE bytes");

    // We can't check beyond IMAGE_SIZE because buffer does not hold it.
}

// 7) Load file: read error during f_read
void test_load_read_failure(TestContext& ctx) {
    reset_environment();
    g_mount_should_fail = false;

    // Put some data in the file
    std::vector<u8> data(IMAGE_SIZE);
    for (size_t i = 0; i < data.size(); ++i) {
        data[i] = static_cast<u8>((i * 5) & 0xFF);
    }
    g_files["img0.raw"] = data;

    g_read_should_fail = true;

    int status = sd_load_file("img0.raw", image_buffer, IMAGE_SIZE);
    ctx.check(status == XST_FAILURE, "Read failure returns XST_FAILURE");

    // Our mocked f_read does not modify dst on failure, so buffer should remain sentinel
    bool untouched = true;
    for (size_t i = 0; i < IMAGE_SIZE; ++i) {
        if (image_buffer[i] != 0xAA) {
            untouched = false;
            break;
        }
    }
    ctx.check(untouched, "Buffer unchanged when f_read fails");
}

// Main: run all tests
int main() {
    TestContext ctx;

    test_mount_success(ctx);
    test_mount_failure(ctx);
    test_load_missing_file(ctx);
    test_load_exact_size(ctx);
    test_load_short_file(ctx);
    test_load_large_file_truncated(ctx);
    test_load_read_failure(ctx);

    std::printf("\n==== TEST SUMMARY ====\n");
    std::printf("Passed: %d\n", ctx.passed);
    std::printf("Failed: %d\n", ctx.failed);

    return (ctx.failed == 0) ? 0 : 1;
}

