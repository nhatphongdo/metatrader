#!/usr/bin/env bash
#
# Build script for MetaTrader 5 EA and Indicator (Mac/Linux)
#
# Compiles all MQ5 files and outputs to build/ directory with proper structure.
# Logs are saved to logs/ directory.
#
# NOTE: MetaTrader 5 on macOS runs through Wine/CrossOver. This script
# attempts to find the MetaEditor installation automatically.
#

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
GRAY='\033[0;90m'
NC='\033[0m' # No Color

# Script directory (project root)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Directories
BUILD_DIR="$SCRIPT_DIR/build"
LOGS_DIR="$SCRIPT_DIR/logs"
EA_SOURCE_DIR="$SCRIPT_DIR/expert-advisor"
INDICATOR_SOURCE_DIR="$SCRIPT_DIR/indicator"
INCLUDE_DIR="$SCRIPT_DIR/include"

# Output directories
EA_BUILD_DIR="$BUILD_DIR/expert-advisor"
INDICATOR_BUILD_DIR="$BUILD_DIR/indicator"

# Flags
CLEAN=false
INSTALL=false
FORCE=false

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --clean|-c)
            CLEAN=true
            shift
            ;;
        --install|-i)
            INSTALL=true
            shift
            ;;
        --force|-f)
            FORCE=true
            shift
            ;;
        --help|-h)
            echo "Usage: $0 [options]"
            echo "Options:"
            echo "  --clean, -c     Clean build directory before compiling"
            echo "  --install, -i   Copy built files to MetaTrader installation folder"
            echo "  --force, -f     Force overwrite without confirmation"
            echo "  --help, -h      Show this help message"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Common MetaEditor paths on macOS (Wine/CrossOver)
find_metaeditor() {
    local search_paths=(
        # PlayOnMac
        "$HOME/Library/PlayOnMac/WinePrefix/MetaTrader*/drive_c/Program Files/MetaTrader 5/metaeditor64.exe"
        "$HOME/Library/PlayOnMac/wineprefix/*/drive_c/Program Files/MetaTrader 5/metaeditor64.exe"
        # Official MetaQuotes Wine wrapper
        "$HOME/Library/Application Support/net.metaquotes.wine.metatrader5/drive_c/Program Files/MetaTrader 5/metaeditor64.exe"
        # CrossOver
        "$HOME/Library/Application Support/CrossOver/Bottles/*/drive_c/Program Files/MetaTrader 5/metaeditor64.exe"
        # Generic Wine prefixes
        "$HOME/.wine/drive_c/Program Files/MetaTrader 5/metaeditor64.exe"
        "$HOME/.wine/drive_c/Program Files (x86)/MetaTrader 5/metaeditor64.exe"
        # Linux common paths
        "/opt/MetaTrader 5/metaeditor64.exe"
        "$HOME/.mt5/drive_c/Program Files/MetaTrader 5/metaeditor64.exe"
    )

    for pattern in "${search_paths[@]}"; do
        # Use compgen to handle glob patterns
        while IFS= read -r -d '' path; do
            if [[ -f "$path" ]]; then
                echo "$path"
                return 0
            fi
        done < <(compgen -G "$pattern" 2>/dev/null | tr '\n' '\0')
    done

    # Check METAEDITOR_PATH environment variable
    if [[ -n "$METAEDITOR_PATH" && -f "$METAEDITOR_PATH" ]]; then
        echo "$METAEDITOR_PATH"
        return 0
    fi

    return 1
}

# Find Wine executable
find_wine() {
    local wine_paths=(
        "/Applications/MetaTrader 5.app/Contents/SharedSupport/wine/bin/wine64"
        "/Applications/MetaTrader 5.app/Contents/SharedSupport/wine/bin/wine"
        "/usr/local/bin/wine64"
        "/usr/local/bin/wine"
        "/opt/homebrew/bin/wine64"
        "/opt/homebrew/bin/wine"
        "/usr/bin/wine64"
        "/usr/bin/wine"
        "$HOME/Library/Application Support/net.metaquotes.wine.metatrader5/wine"
    )

    for path in "${wine_paths[@]}"; do
        if [[ -x "$path" ]]; then
            echo "$path"
            return 0
        fi
    done

    # Try which
    if command -v wine64 &> /dev/null; then
        which wine64
        return 0
    fi

    if command -v wine &> /dev/null; then
        which wine
        return 0
    fi

    return 1
}

# Initialize directories
initialize_directories() {
    for dir in "$BUILD_DIR" "$LOGS_DIR" "$EA_BUILD_DIR" "$INDICATOR_BUILD_DIR"; do
        if [[ ! -d "$dir" ]]; then
            mkdir -p "$dir"
            echo -e "${GRAY}Created directory: $dir${NC}"
        fi
    done

    if [[ "$CLEAN" == true ]]; then
        echo -e "${YELLOW}Cleaning build directory...${NC}"
        rm -rf "$EA_BUILD_DIR"/* 2>/dev/null || true
        rm -rf "$INDICATOR_BUILD_DIR"/* 2>/dev/null || true
    fi
}

# Convert Unix path to Windows path for Wine
unix_to_wine_path() {
    local unix_path="$1"
    # Find drive_c in the path and convert accordingly
    if [[ "$unix_path" == *"drive_c"* ]]; then
        # Extract the part after drive_c and convert
        local win_path="${unix_path#*drive_c/}"
        win_path="C:\\${win_path//\//\\}"
        echo "$win_path"
    else
        # Use winepath if available
        if command -v winepath &> /dev/null; then
            winepath -w "$unix_path" 2>/dev/null || echo "$unix_path"
        else
            # Manual fallback: map root / to Z:\ and replace slashes
            if [[ "$unix_path" == /* ]]; then
               echo "Z:${unix_path//\//\\}"
            else
               echo "$unix_path"
            fi
        fi
    fi
}

# Compile MQ5 file
compile_mq5() {
    local source_file="$1"
    local output_dir="$2"
    local log_file="$3"
    local metaeditor="$4"
    local wine_cmd="$5"

    local file_name=$(basename "$source_file" .mq5)

    echo -e "  ${CYAN}Compiling: ${file_name}.mq5${NC}"

    # Convert paths for Wine
    local wine_source=$(unix_to_wine_path "$source_file")
    local wine_log=$(unix_to_wine_path "$log_file")

    # Set WINEPREFIX based on MetaEditor location to avoid hang
    # Assumes standard structure .../drive_c/Program Files/...
    local wine_prefix=$(echo "$metaeditor" | sed 's|/drive_c/.*||')
    if [[ -d "$wine_prefix" ]]; then
        export WINEPREFIX="$wine_prefix"
    fi

    # Run MetaEditor through Wine
    if [[ -n "$wine_cmd" ]]; then
        WINEDEBUG=-all "$wine_cmd" "$metaeditor" /compile:"$wine_source" /log:"$wine_log" 2>/dev/null || true
    else
        # Direct execution (unlikely on Mac but possible on some setups)
        "$metaeditor" /compile:"$wine_source" /log:"$wine_log" 2>/dev/null || true
    fi

    sleep 1

    # Check log for results
    if [[ -f "$log_file" ]]; then
        # Try to convert UTF-16LE (MT5 standard) to UTF-8, fallback to cat if that fails
        local log_content=$(iconv -f UTF-16LE -t UTF-8 "$log_file" 2>/dev/null || cat "$log_file" 2>/dev/null || echo "")

        local errors=$(echo "$log_content" | grep -oE '[0-9]+ error' | grep -oE '[0-9]+' | head -1 || echo "0")
        local warnings=$(echo "$log_content" | grep -oE '[0-9]+ warning' | grep -oE '[0-9]+' | head -1 || echo "0")

        errors=${errors:-0}
        warnings=${warnings:-0}

        if [[ "$errors" -gt 0 ]]; then
            echo -e "    ${RED}FAILED: $errors error(s), $warnings warning(s)${NC}"
            return 1
        else
            echo -e "    ${GREEN}SUCCESS: $errors error(s), $warnings warning(s)${NC}"

            # Find and move .ex5 file to build directory
            local source_dir=$(dirname "$source_file")
            local ex5_source="$source_dir/${file_name}.ex5"
            if [[ -f "$ex5_source" ]]; then
                cp "$ex5_source" "$output_dir/"
                rm -f "$ex5_source"  # Xóa file .ex5 từ source
                echo -e "    ${GRAY}Output: $output_dir/${file_name}.ex5${NC}"
            fi
            return 0
        fi
    fi

    echo -e "    ${YELLOW}WARNING: Could not read log file${NC}"
    return 1
}

# ============== MAIN ==============

echo ""
echo -e "${CYAN}========================================${NC}"
echo -e "${CYAN}   MetaTrader 5 Build Script (Mac/Linux)${NC}"
echo -e "${CYAN}========================================${NC}"
echo ""

# Find MetaEditor
METAEDITOR=$(find_metaeditor || true)
if [[ -z "$METAEDITOR" ]]; then
    echo -e "${RED}ERROR: MetaEditor64.exe not found!${NC}"
    echo -e "${YELLOW}Please install MetaTrader 5 or set METAEDITOR_PATH environment variable.${NC}"
    echo ""
    echo "Expected locations:"
    echo "  - PlayOnMac: ~/Library/PlayOnMac/WinePrefix/..."
    echo "  - Official: ~/Library/Application Support/net.metaquotes.wine.metatrader5/..."
    echo "  - Wine: ~/.wine/drive_c/Program Files/MetaTrader 5/"
    echo ""
    exit 1
fi

echo -e "${GRAY}MetaEditor: $METAEDITOR${NC}"

# Find Wine
WINE_CMD=$(find_wine || true)
if [[ -z "$WINE_CMD" ]]; then
    echo -e "${YELLOW}WARNING: Wine not found. Attempting direct execution...${NC}"
fi
echo -e "${GRAY}Wine: ${WINE_CMD:-N/A}${NC}"
echo ""

# Initialize directories
initialize_directories

TOTAL_ERRORS=0
TOTAL_SUCCESS=0

# Compile Expert Advisors
echo -e "${YELLOW}[Expert Advisors]${NC}"
if [[ -d "$EA_SOURCE_DIR" ]]; then
    for file in "$EA_SOURCE_DIR"/*.mq5; do
        if [[ -f "$file" ]]; then
            file_name=$(basename "$file" .mq5)
            log_file="$LOGS_DIR/ea_${file_name}.log"
            if compile_mq5 "$file" "$EA_BUILD_DIR" "$log_file" "$METAEDITOR" "$WINE_CMD"; then
                ((TOTAL_SUCCESS++))
            else
                ((TOTAL_ERRORS++))
            fi
        fi
    done
else
    echo -e "  ${GRAY}No EA directory found.${NC}"
fi

echo ""

# Compile Indicators
echo -e "${YELLOW}[Indicators]${NC}"
if [[ -d "$INDICATOR_SOURCE_DIR" ]]; then
    for file in "$INDICATOR_SOURCE_DIR"/*.mq5; do
        if [[ -f "$file" ]]; then
            file_name=$(basename "$file" .mq5)
            log_file="$LOGS_DIR/indicator_${file_name}.log"
            if compile_mq5 "$file" "$INDICATOR_BUILD_DIR" "$log_file" "$METAEDITOR" "$WINE_CMD"; then
                ((TOTAL_SUCCESS++))
            else
                ((TOTAL_ERRORS++))
            fi
        fi
    done
else
    echo -e "  ${GRAY}No Indicator directory found.${NC}"
fi

# Install to MT5 if requested
if [[ "$INSTALL" == true && $TOTAL_ERRORS -eq 0 && $TOTAL_SUCCESS -gt 0 ]]; then
    echo ""
    echo -e "${YELLOW}[Installing to MetaTrader 5]${NC}"

    # MT5 stores user data in Wine prefix AppData, not in Program Files
    # Find the MQL5 folder in drive_c/users/.../AppData/Roaming/MetaQuotes/Terminal/<ID>/
    MT5_DATA_PATH=""

    # Get Wine prefix from MetaEditor path (find drive_c parent)
    WINE_PREFIX=$(echo "$METAEDITOR" | sed 's|/drive_c/.*|/drive_c|')

    if [[ -d "$WINE_PREFIX" ]]; then
        # Search for MetaQuotes Terminal folder
        TERMINAL_PATH="$WINE_PREFIX/users/$USER/AppData/Roaming/MetaQuotes/Terminal"
        if [[ ! -d "$TERMINAL_PATH" ]]; then
            # Try common Windows username patterns
            TERMINAL_PATH=$(find "$WINE_PREFIX/users" -path "*/AppData/Roaming/MetaQuotes/Terminal" -type d 2>/dev/null | head -1)
        fi

        if [[ -d "$TERMINAL_PATH" ]]; then
            # Find first terminal with MQL5 subdirectory
            for terminal_dir in "$TERMINAL_PATH"/*/; do
                if [[ -d "${terminal_dir}MQL5" ]]; then
                    MT5_DATA_PATH="${terminal_dir}MQL5"
                    break
                fi
            done
        fi
    fi

    # Fallback: try same directory as MetaEditor
    if [[ -z "$MT5_DATA_PATH" ]]; then
        MT5_PATH=$(dirname "$METAEDITOR")
        if [[ -d "$MT5_PATH/MQL5" ]]; then
            MT5_DATA_PATH="$MT5_PATH/MQL5"
        fi
    fi

    if [[ -z "$MT5_DATA_PATH" ]]; then
        echo -e "  ${YELLOW}WARNING: MT5 data folder not found${NC}"
        INSTALLED_COUNT=0
    else
        echo -e "  ${GRAY}MT5 Data: $MT5_DATA_PATH${NC}"
        MT5_EXPERTS_DIR="$MT5_DATA_PATH/Experts"
        MT5_INDICATORS_DIR="$MT5_DATA_PATH/Indicators"
    fi

    INSTALLED_COUNT=0

    # Install EAs
    if [[ -d "$MT5_EXPERTS_DIR" ]]; then
        for file in "$EA_BUILD_DIR"/*.ex5; do
            if [[ -f "$file" ]]; then
                file_name=$(basename "$file")
                dest_path="$MT5_EXPERTS_DIR/$file_name"
                should_copy=true

                if [[ -f "$dest_path" ]]; then
                    if [[ "$FORCE" == true ]]; then
                        echo -e "  ${YELLOW}Overwriting: $file_name${NC}"
                    else
                        echo -e "  ${YELLOW}File exists: $file_name${NC}"
                        read -p "    Overwrite? (y/N) " response
                        if [[ "$response" != "y" && "$response" != "Y" ]]; then
                            echo -e "    ${GRAY}Skipped.${NC}"
                            should_copy=false
                        fi
                    fi
                fi

                if [[ "$should_copy" == true ]]; then
                    cp "$file" "$dest_path"
                    echo -e "  ${GREEN}Installed EA: $file_name -> $MT5_EXPERTS_DIR${NC}"
                    ((INSTALLED_COUNT++))
                fi
            fi
        done
    else
        echo -e "  ${YELLOW}WARNING: MT5 Experts folder not found: $MT5_EXPERTS_DIR${NC}"
    fi

    # Install Indicators
    if [[ -d "$MT5_INDICATORS_DIR" ]]; then
        for file in "$INDICATOR_BUILD_DIR"/*.ex5; do
            if [[ -f "$file" ]]; then
                file_name=$(basename "$file")
                dest_path="$MT5_INDICATORS_DIR/$file_name"
                should_copy=true

                if [[ -f "$dest_path" ]]; then
                    if [[ "$FORCE" == true ]]; then
                        echo -e "  ${YELLOW}Overwriting: $file_name${NC}"
                    else
                        echo -e "  ${YELLOW}File exists: $file_name${NC}"
                        read -p "    Overwrite? (y/N) " response
                        if [[ "$response" != "y" && "$response" != "Y" ]]; then
                            echo -e "    ${GRAY}Skipped.${NC}"
                            should_copy=false
                        fi
                    fi
                fi

                if [[ "$should_copy" == true ]]; then
                    cp "$file" "$dest_path"
                    echo -e "  ${GREEN}Installed Indicator: $file_name -> $MT5_INDICATORS_DIR${NC}"
                    ((INSTALLED_COUNT++))
                fi
            fi
        done
    else
        echo -e "  ${YELLOW}WARNING: MT5 Indicators folder not found: $MT5_INDICATORS_DIR${NC}"
    fi

    echo -e "  ${CYAN}Total installed: $INSTALLED_COUNT file(s)${NC}"
fi

echo ""
echo -e "${CYAN}========================================${NC}"
echo -e "${CYAN}Build Summary:${NC}"
echo -e "  ${GREEN}Success: $TOTAL_SUCCESS${NC}"
if [[ $TOTAL_ERRORS -gt 0 ]]; then
    echo -e "  ${RED}Failed:  $TOTAL_ERRORS${NC}"
else
    echo -e "  ${GRAY}Failed:  $TOTAL_ERRORS${NC}"
fi
echo -e "  ${GRAY}Logs:    $LOGS_DIR${NC}"
echo -e "  ${GRAY}Output:  $BUILD_DIR${NC}"
echo -e "${CYAN}========================================${NC}"
echo ""

if [[ $TOTAL_ERRORS -gt 0 ]]; then
    exit 1
fi
exit 0
