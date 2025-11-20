#!/bin/bash
# DTS Compiler Script for ImmortalWrt
# Usage: ./compile-dts.sh <path-to-dts-file>
# Run from ImmortalWrt root directory

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Get ImmortalWrt root directory
IMWRT_ROOT="$(pwd)"

# Check arguments
if [ $# -eq 0 ]; then
    echo -e "${RED}Error: No DTS file specified${NC}"
    echo "Usage: ./compile-dts.sh <path-to-dts-file>"
    echo "Example: ./compile-dts.sh target/linux/rockchip/files/arch/arm64/boot/dts/rockchip/rk3568-100ask-dshanpi-r1.dts"
    exit 1
fi

DTS_FILE="$1"

# Resolve path
if [[ "$DTS_FILE" = /* ]]; then
    DTS_ABS="$DTS_FILE"
else
    DTS_ABS="${IMWRT_ROOT}/${DTS_FILE}"
fi

# Check if file exists
if [ ! -f "$DTS_ABS" ]; then
    echo -e "${RED}Error: DTS file not found: $DTS_ABS${NC}"
    exit 1
fi

DTS_DIR=$(dirname "$DTS_ABS")
DTS_NAME=$(basename "$DTS_FILE" .dts)
DTB_OUTPUT="${DTS_DIR}/${DTS_NAME}.dtb"

# Find kernel build directory
KERNEL_DIR=$(find "${IMWRT_ROOT}"/build_dir/target-*/linux-*/linux-* -maxdepth 0 -type d 2>/dev/null | head -1)

if [ -z "$KERNEL_DIR" ]; then
    echo -e "${RED}Error: Kernel build directory not found${NC}"
    echo "Please build the kernel first with: make target/linux/compile"
    exit 1
fi

DTC="${KERNEL_DIR}/scripts/dtc/dtc"
if [ ! -f "$DTC" ]; then
    echo -e "${RED}Error: dtc compiler not found at $DTC${NC}"
    exit 1
fi

# Include paths for DTS compilation
INCLUDE_PATHS=(
    "-i${DTS_DIR}"
    "-i${KERNEL_DIR}/arch/arm64/boot/dts"
    "-i${KERNEL_DIR}/arch/arm64/boot/dts/rockchip"
    "-i${KERNEL_DIR}/include"
)

echo -e "${GREEN}[INFO]${NC} Device Tree Compiler for ImmortalWrt"
echo -e "${GREEN}[INFO]${NC} DTS File: $DTS_FILE"
echo -e "${GREEN}[INFO]${NC} Output:   $DTB_OUTPUT"
echo -e "${GREEN}[INFO]${NC} Kernel directory: $KERNEL_DIR"

# Preprocess DTS
echo -e "${GREEN}[INFO]${NC} Preprocessing DTS file..."
DTS_TMP=$(mktemp --suffix=.dts)
cpp -nostdinc \
    -I"${DTS_DIR}" \
    -I"${KERNEL_DIR}/arch/arm64/boot/dts" \
    -I"${KERNEL_DIR}/arch/arm64/boot/dts/rockchip" \
    -I"${KERNEL_DIR}/include" \
    -undef -x assembler-with-cpp \
    "$DTS_ABS" "$DTS_TMP" 2>&1 | grep -v "^#" || true

# Compile DTB
echo -e "${GREEN}[INFO]${NC} Compiling DTB..."
"$DTC" -I dts -O dtb -o "$DTB_OUTPUT" "${INCLUDE_PATHS[@]}" "$DTS_TMP"

# Cleanup
rm -f "$DTS_TMP"

# Check output
if [ -f "$DTB_OUTPUT" ]; then
    DTB_SIZE=$(stat -c%s "$DTB_OUTPUT")
    echo -e "${GREEN}[INFO]${NC} Success! DTB file created: $DTB_OUTPUT"
    echo -e "${GREEN}[INFO]${NC} DTB size: $DTB_SIZE bytes"
    
    # Show DTB info
    echo -e "${GREEN}[INFO]${NC} DTB Information:"
    "$DTC" -I dtb -O dts "$DTB_OUTPUT" 2>/dev/null | head -20
    echo -e "${GREEN}[INFO]${NC} Done!"
else
    echo -e "${RED}[ERROR]${NC} Failed to create DTB file"
    exit 1
fi
