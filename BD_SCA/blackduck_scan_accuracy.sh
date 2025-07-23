#!/bin/bash
#
# Script: blackduck_scan_accuracy.sh
# Version: 2.0.1 (Security Enhanced to obfuscate the BD Server's API Token on the screen)
#
# Type: Interactive Tool
# Purpose: Educational Black Duck scan wrapper that helps users understand different
#          scanning strategies and their trade-offs while performing an actual scan.
#          Examples include scanning the same application using different scan
#          matching types and either including or excluding devDependenices.
#
#          This script then prints the output of the command to the screen to show
#          what those options actually were.
#
# Environment Requirements:
#   BLACKDUCK_URL       - Your Black Duck instance URL
#   BLACKDUCK_API_TOKEN - Your API token
#   DETECT_JAR          - Path to Synopsys Detect (optional, auto-detects)
#
#   The intent is to completely exclude sensitive credentials from the script. You'll
#   need to export your BLACKDUCK_URL and BLACKDUCK_API_TOKEN so that the script can
#   pick them up.
#
#   Example for Linux:
#
#   $ sudo export BLACKDUCK_URL=https://your.bdserver_url_here
#   $ sudo export BLACKDUCK_API_TOKEN=whatever_that_is_goes_here
#
# Supports: npm, Maven, Gradle, pip, .NET, Go, and other Detect-supported ecosystems
#          Plus Docker container scanning (requires BDSC license)
#
# Usage: ./blackduck_scan_accuracy.sh
#        Interactive prompts will guide you through scan configuration
#

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

# Function to safely display API tokens with obfuscation
obfuscate_token() {
    local token="$1"
    local show_chars="${2:-8}"  # Default to 8 characters, but allow override

    if [ -z "$token" ]; then
        echo "[NOT SET]"
        return 1
    fi

    local token_length=${#token}

    if [ $token_length -le $show_chars ]; then
        # If token is shorter than show_chars, show all but last 2 chars
        local visible_chars=$((token_length - 2))
        if [ $visible_chars -lt 1 ]; then
            echo "***"
        else
            echo "${token:0:$visible_chars}***"
        fi
    else
        # Show first N characters and obfuscate the rest
        local visible_part="${token:0:$show_chars}"
        local hidden_length=$((token_length - show_chars))
        local asterisks=$(printf "%*s" $hidden_length | tr ' ' '*')
        echo "${visible_part}${asterisks}"
    fi
}

# Function to safely display URL (obfuscate any embedded credentials)
obfuscate_url() {
    local url="$1"

    if [ -z "$url" ]; then
        echo "[NOT SET]"
        return 1
    fi

    # Check if URL contains credentials (user:pass@host pattern)
    if [[ "$url" =~ ://([^:]+):([^@]+)@(.+) ]]; then
        local protocol="${url%%://*}"
        local user="${BASH_REMATCH[1]}"
        local pass="${BASH_REMATCH[2]}"
        local host="${BASH_REMATCH[3]}"

        # Obfuscate the password part
        local obfuscated_pass=$(obfuscate_token "$pass" 3)
        echo "${protocol}://${user}:${obfuscated_pass}@${host}"
    else
        # No credentials in URL, safe to display
        echo "$url"
    fi
}

# Binary file patterns
BINARY_PATTERNS=(
    "*.exe" "*.dll" "*.msi"           # Windows
    "*.so" "*.a" "*.deb" "*.rpm"      # Linux
    "*.dylib" "*.dmg"                 # macOS
    "*.jar" "*.war" "*.ear" "*.class" # Java
    "*.nupkg"                         # .NET packages
    "*.pyc" "*.pyo" "*.whl"          # Python
    "*.node"                          # Node.js native modules
    "*.wasm"                          # WebAssembly
    "*.o" "*.lib"                     # Object files
)

# Function to detect Synopsys Detect JAR
detect_jar_path() {
    # First check if DETECT_JAR is already set and valid
    if [ -n "$DETECT_JAR" ] && [ -f "$DETECT_JAR" ]; then
        echo "$DETECT_JAR"
        return 0
    fi

    # Check for the version file in the standard location
    local detect_dir="$HOME/detect/download"
    local version_file="$detect_dir/detect-last-downloaded-jar.txt"

    if [ -f "$version_file" ]; then
        local jar_name=$(cat "$version_file" | tr -d '\n')
        local jar_path="$detect_dir/$jar_name"

        if [ -f "$jar_path" ]; then
            echo "$jar_path"
            return 0
        fi
    fi

    # Fallback: look for any detect jar in the download directory
    if [ -d "$detect_dir" ]; then
        local latest_jar=$(ls -t "$detect_dir"/detect-*.jar 2>/dev/null | head -1)
        if [ -f "$latest_jar" ]; then
            echo "$latest_jar"
            return 0
        fi
    fi

    # Last resort: check common locations
    for location in \
        "$HOME/detect/synopsys-detect-latest.jar" \
        "$HOME/detect/detect.jar" \
        "./detect.jar" \
        "./synopsys-detect.jar"
    do
        if [ -f "$location" ]; then
            echo "$location"
            return 0
        fi
    done

    return 1
}

# Configuration
DETECT_JAR=$(detect_jar_path)
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

# Global variables
FOUND_BINARIES=""
BINARY_EXAMPLES=""
DOCKER_AVAILABLE=false
CONTAINERS_FOUND=""
PROJECT_NAME_FOR_CONTAINERS=""

# Function to check Docker availability
check_docker() {
    if command -v docker &> /dev/null && docker ps &> /dev/null; then
        DOCKER_AVAILABLE=true
        echo -e "${GREEN}✓ Docker is available${NC}"
        return 0
    else
        DOCKER_AVAILABLE=false
        echo -e "${YELLOW}⚠ Docker not available or not running${NC}"
        return 1
    fi
}

# Function to detect related containers
detect_containers() {
    if [ "$DOCKER_AVAILABLE" != "true" ]; then
        return 1
    fi

    # Get the project name to search for
    local search_name="$1"
    if [ -z "$search_name" ]; then
        return 1
    fi

    echo -e "${CYAN}Scanning for related containers...${NC}"

    # Clean project name for matching (remove special chars, convert to lowercase)
    local clean_name=$(echo "$search_name" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9-]//g' | sed 's/-production$//')

    # Extract common prefixes from project name (split by hyphens)
    local name_parts=($(echo "$clean_name" | tr '-' ' '))
    local search_patterns=()

    # Build search patterns from name parts
    search_patterns+=("$clean_name")  # Full name

    # Create partial patterns
    if [ ${#name_parts[@]} -gt 2 ]; then
        for ((i=2; i<=${#name_parts[@]}; i++)); do
            partial=$(echo "${name_parts[@]:0:$i}" | tr ' ' '-')
            search_patterns+=("$partial")
        done
    fi

    # Also try first two parts only
    if [ ${#name_parts[@]} -ge 2 ]; then
        search_patterns+=("${name_parts[0]}-${name_parts[1]}")
    fi

    # And just the first part
    search_patterns+=("${name_parts[0]}")

    # Remove duplicates
    search_patterns=($(echo "${search_patterns[@]}" | tr ' ' '\n' | sort -u | tr '\n' ' '))

    echo -e "${CYAN}Search patterns: ${search_patterns[*]}${NC}"

    # Get all containers (running and stopped)
    local all_containers=$(docker ps -a --format "{{.ID}}|{{.Names}}|{{.Image}}|{{.Status}}")

    # Look for containers matching project patterns
    CONTAINERS_FOUND=""
    local container_count=0
    while IFS='|' read -r id name image status; do
        # Skip empty entries
        if [ -z "$name" ] || [ -z "$id" ]; then
            continue
        fi

        # Check each pattern
        for pattern in "${search_patterns[@]}"; do
            # More flexible matching
            if [[ "$name" =~ $pattern ]] || \
               [[ "$name" =~ ^${pattern}- ]] || \
               [[ "$name" =~ -${pattern}$ ]] || \
               [[ "$name" =~ _${pattern}_ ]] || \
               [[ "$name" =~ ^${pattern}_ ]] || \
               [[ "$name" =~ _${pattern}$ ]]; then
                # Use ╬ as delimiter between containers
                if [ -z "$CONTAINERS_FOUND" ]; then
                    CONTAINERS_FOUND="${id}|${name}|${image}|${status}"
                else
                    # Check for duplicates
                    if [[ ! "$CONTAINERS_FOUND" =~ "${id}\|${name}\|${image}" ]]; then
                        CONTAINERS_FOUND="${CONTAINERS_FOUND}╬${id}|${name}|${image}|${status}"
                    fi
                fi
                ((container_count++))

                # Display the found container
                if [[ "$status" =~ ^Up ]]; then
                    echo -e "${GREEN}  • $name ($image) - Running${NC}"
                else
                    echo -e "${YELLOW}  • $name ($image) - Stopped${NC}"
                fi
                break
            fi
        done
    done <<< "$all_containers"

    if [ $container_count -gt 0 ]; then
        echo -e "${GREEN}✓ Found ${container_count} potentially related container(s)${NC}"
        return 0
    else
        echo -e "${YELLOW}No containers found matching project name patterns${NC}"
        echo -e "${YELLOW}Searched for: ${search_patterns[*]}${NC}"
        CONTAINERS_FOUND=""
        return 1
    fi
}

# Function to check container size
check_container_size() {
    local container_name=$1
    local size_output=$(docker ps -a --filter "name=$container_name" --format "table {{.Size}}" | tail -n 1)

    # Extract numeric size
    if [[ "$size_output" =~ ([0-9.]+)GB ]]; then
        local size_gb=${BASH_REMATCH[1]}
        if (( $(echo "$size_gb > 1" | bc -l) )); then
            echo -e "${YELLOW}Warning: Container $container_name is ${size_gb}GB (>1GB)${NC}"
            echo -e "${YELLOW}Saving and scanning may take several minutes...${NC}"
            return 1
        fi
    fi
    return 0
}

# Function to save and scan a container
scan_container() {
    local container_id=$1
    local container_name=$2
    local container_image=$3
    local temp_file="/tmp/${container_name}_${TIMESTAMP}.tar"

    echo -e "\n${BLUE}Saving container $container_name...${NC}"

    # Check container size
    check_container_size "$container_name"

    # Save the image (not the container ID)
    echo -e "${CYAN}Saving image $container_image used by container $container_name...${NC}"
    if docker save "$container_image" -o "$temp_file"; then
        echo -e "${GREEN}✓ Container image saved to temporary file${NC}"

        # Get file size
        local file_size=$(du -h "$temp_file" | cut -f1)
        echo -e "${CYAN}  File size: $file_size${NC}"

        # Scan the container
        echo -e "\n${BLUE}Scanning container $container_name...${NC}"

        java -jar $DETECT_JAR \
            --blackduck.url=$BLACKDUCK_URL \
            --blackduck.api.token=$BLACKDUCK_API_TOKEN \
            --blackduck.trust.cert=true \
            --detect.project.name="$PROJECT_NAME_FOR_CONTAINERS/containers" \
            --detect.project.version.name="$container_name" \
            --detect.project.description="Container scan for $container_name ($container_image) - This was scanned with blackduck_scan_accuracy.sh for educational purposes" \
            --detect.project.version.phase=RELEASED \
            --detect.tools=CONTAINER_SCAN \
            --detect.container.scan.file.path="$temp_file" \
            --detect.output.path="/tmp/detect-container-$container_name"

        local scan_result=$?

        # Clean up
        echo -e "\n${BLUE}Cleaning up temporary files...${NC}"
        rm -f "$temp_file"
        echo -e "${GREEN}✓ Temporary files removed${NC}"

        if [ $scan_result -eq 0 ]; then
            echo -e "${GREEN}✓ Container scan complete for $container_name${NC}"
        else
            echo -e "${YELLOW}⚠ Container scan completed with warnings or errors for $container_name${NC}"
        fi
    else
        echo -e "${RED}✗ Failed to save image $container_image for container $container_name${NC}"
    fi
}

# Updated check_prerequisites function with secure credential display
check_prerequisites() {
    local missing=0

    echo -e "${CYAN}Checking prerequisites...${NC}"

    if [ -z "$BLACKDUCK_URL" ]; then
        echo -e "${RED}✗ BLACKDUCK_URL not set${NC}"
        missing=1
    else
        local safe_url=$(obfuscate_url "$BLACKDUCK_URL")
        echo -e "${GREEN}✓ BLACKDUCK_URL found: ${safe_url}${NC}"
    fi

    if [ -z "$BLACKDUCK_API_TOKEN" ]; then
        echo -e "${RED}✗ BLACKDUCK_API_TOKEN not set${NC}"
        missing=1
    else
        local safe_token=$(obfuscate_token "$BLACKDUCK_API_TOKEN" 8)
        echo -e "${GREEN}✓ BLACKDUCK_API_TOKEN found: ${safe_token}${NC}"
    fi

    if [ -z "$DETECT_JAR" ] || [ ! -f "$DETECT_JAR" ]; then
        echo -e "${RED}✗ Detect JAR not found${NC}"
        echo -e "${YELLOW}  Please download from: https://detect.synopsys.com${NC}"
        echo -e "${YELLOW}  Or set DETECT_JAR environment variable${NC}"
        missing=1
    else
        echo -e "${GREEN}✓ Detect JAR found: $(basename $DETECT_JAR)${NC}"
    fi

    # Check Docker
    check_docker

    if [ $missing -eq 1 ]; then
        echo ""
        echo -e "${RED}Missing prerequisites. Please:${NC}"
        echo "1. Set environment variables:"
        echo "   export BLACKDUCK_URL='https://your-instance.blackduck.com'"
        echo "   export BLACKDUCK_API_TOKEN='your-api-token'"
        echo "2. Download Detect from https://detect.synopsys.com"
        exit 1
    fi
    echo ""
}

# Function to detect project information
detect_project_info() {
    local DEFAULT_NAME=""
    local DEFAULT_VERSION=""
    local PROJECT_TYPE=""

    if [ -f "package.json" ]; then
        DEFAULT_NAME=$(grep '"name"' package.json | head -1 | cut -d'"' -f4 || echo "")
        DEFAULT_VERSION=$(grep '"version"' package.json | head -1 | cut -d'"' -f4 || echo "")
        PROJECT_TYPE="npm"
    elif [ -f "pom.xml" ]; then
        DEFAULT_NAME=$(grep -m1 '<artifactId>' pom.xml | sed 's/.*<artifactId>\(.*\)<\/artifactId>.*/\1/' || echo "")
        DEFAULT_VERSION=$(grep -m1 '<version>' pom.xml | sed 's/.*<version>\(.*\)<\/version>.*/\1/' || echo "")
        PROJECT_TYPE="maven"
    elif [ -f "build.gradle" ] || [ -f "build.gradle.kts" ]; then
        DEFAULT_NAME=$(grep "rootProject.name" settings.gradle* 2>/dev/null | cut -d"'" -f2 | cut -d'"' -f2 || echo "")
        DEFAULT_VERSION=$(grep "version" build.gradle* | grep -v "id" | head -1 | cut -d"'" -f2 | cut -d'"' -f2 || echo "")
        PROJECT_TYPE="gradle"
    elif [ -f "requirements.txt" ] || [ -f "setup.py" ] || [ -f "Pipfile" ]; then
        if [ -f "setup.py" ]; then
            DEFAULT_NAME=$(grep "name=" setup.py | head -1 | cut -d"'" -f2 | cut -d'"' -f2 || echo "")
            DEFAULT_VERSION=$(grep "version=" setup.py | head -1 | cut -d"'" -f2 | cut -d'"' -f2 || echo "")
        fi
        PROJECT_TYPE="python"
    elif [ -f "go.mod" ]; then
        DEFAULT_NAME=$(grep "module" go.mod | awk '{print $2}' | rev | cut -d'/' -f1 | rev || echo "")
        PROJECT_TYPE="go"
    elif ls *.csproj >/dev/null 2>&1 || ls *.sln >/dev/null 2>&1; then
        PROJECT_TYPE="dotnet"
    else
        PROJECT_TYPE="unknown"
    fi

    echo "$DEFAULT_NAME|$DEFAULT_VERSION|$PROJECT_TYPE"
}

# Function to explain what the scan will do
explain_scan() {
    local scan_type=$1
    echo -e "\n${CYAN}═══ What This Scan Does ═══${NC}"

    case $scan_type in
        "production")
            echo "• Scans ONLY your build/production directory"
            echo "• Uses signature matching on compiled code"
            echo "• Shows what's actually in your production artifacts"
            echo ""
            echo -e "${YELLOW}Note: Won't show your declared dependencies${NC}"
            ;;
        "dependencies")
            echo "• Reads your package manager files"
            echo "• Identifies all production dependencies"
            echo "• Matches against Black Duck KnowledgeBase"
            echo "• Reports licenses and known vulnerabilities"
            echo ""
            echo -e "${YELLOW}Note: DevDependencies excluded by default for accuracy${NC}"
            ;;
        "full")
            echo "• Everything from Dependencies scan, PLUS:"
            echo "• Scans source files for code signatures"
            echo "• Can scan entire codebase OR just build directory"
            echo "• May identify copy/pasted open source code"
            echo "• Can detect components not in package files"
            echo ""
            echo -e "${YELLOW}Note: Build-only scan is more accurate than full codebase${NC}"
            ;;
        "container")
            echo "• Saves Docker container as tar file"
            echo "• Analyzes all layers in the container"
            echo "• Identifies OS packages and libraries"
            echo "• Detects vulnerabilities in container components"
            echo ""
            echo -e "${YELLOW}Note: Requires BDSC license and MaaS enabled${NC}"
            ;;
    esac
    echo ""
}

# Function to detect build directories
detect_build_directories() {
    local FOUND_DIRS=()

    # JavaScript/TypeScript
    [ -d ".next" ] && FOUND_DIRS+=(".next")
    [ -d "build" ] && FOUND_DIRS+=("build")
    [ -d "dist" ] && FOUND_DIRS+=("dist")
    [ -d "out" ] && FOUND_DIRS+=("out")
    [ -d "public" ] && [ -f "package.json" ] && FOUND_DIRS+=("public")
    [ -d ".nuxt" ] && FOUND_DIRS+=(".nuxt")

    # Java
    [ -d "target" ] && FOUND_DIRS+=("target")
    [ -d "target/classes" ] && FOUND_DIRS+=("target/classes")

    # Python
    [ -d "_build" ] && FOUND_DIRS+=("_build")
    [ -d "build" ] && [ -f "setup.py" ] && FOUND_DIRS+=("build")
    [ -d "dist" ] && [ -f "setup.py" ] && FOUND_DIRS+=("dist")

    # .NET
    [ -d "bin/Release" ] && FOUND_DIRS+=("bin/Release")
    [ -d "bin/Debug" ] && FOUND_DIRS+=("bin/Debug")
    [ -d "publish" ] && FOUND_DIRS+=("publish")

    # Go
    [ -d "bin" ] && FOUND_DIRS+=("bin")

    # Rust
    [ -d "target/release" ] && FOUND_DIRS+=("target/release")
    [ -d "target/debug" ] && FOUND_DIRS+=("target/debug")

    echo "${FOUND_DIRS[@]}"
}

# Function to get project info interactively
get_project_info() {
    local suffix=$1
    local project_data=$2

    IFS='|' read -r DEFAULT_NAME DEFAULT_VERSION PROJECT_TYPE <<< "$project_data"

    if [ -n "$DEFAULT_NAME" ] || [ -n "$DEFAULT_VERSION" ]; then
        echo -e "${CYAN}Detected: ${GREEN}$DEFAULT_NAME${NC} v${GREEN}$DEFAULT_VERSION${NC} (${PROJECT_TYPE})"
    fi

    # Project name
    if [ -n "$DEFAULT_NAME" ]; then
        read -p "$(echo -e ${GREEN}Project name [$DEFAULT_NAME$suffix]: ${NC})" PROJECT_NAME
        PROJECT_NAME=${PROJECT_NAME:-$DEFAULT_NAME$suffix}
    else
        read -p "$(echo -e ${GREEN}Project name: ${NC})" PROJECT_NAME
        PROJECT_NAME="$PROJECT_NAME$suffix"
    fi

    # Project version
    if [ -n "$DEFAULT_VERSION" ]; then
        read -p "$(echo -e ${GREEN}Version [$DEFAULT_VERSION]: ${NC})" PROJECT_VERSION
        PROJECT_VERSION=${PROJECT_VERSION:-$DEFAULT_VERSION}
    else
        read -p "$(echo -e ${GREEN}Version: ${NC})" PROJECT_VERSION
    fi

    # Export for use in calling context
    export PROJECT_NAME PROJECT_VERSION PROJECT_TYPE
}

# Function to get exclude dev dependencies flag based on project type
get_exclude_dev_flag() {
    local project_type=$1
    local include_dev=$2

    if [ "$include_dev" = "y" ]; then
        echo ""
        return
    fi

    case $project_type in
        npm)
            echo "--detect.npm.dependency.types.excluded=DEV"
            ;;
        maven)
            echo "--detect.maven.excluded.scopes=test,provided"
            ;;
        gradle)
            echo "--detect.gradle.excluded.configurations=testCompile,testImplementation"
            ;;
        python)
            echo "--detect.pip.only.project.tree=true"
            ;;
        *)
            echo ""
            ;;
    esac
}

# Function to select build directory
select_build_directory() {
    local FOUND_DIRS=($@)

    echo -e "\n${CYAN}Detecting build directories...${NC}"

    if [ ${#FOUND_DIRS[@]} -gt 0 ]; then
        echo -e "${GREEN}Found the following build directories:${NC}"
        for i in "${!FOUND_DIRS[@]}"; do
            dir_size=$(du -sh "${FOUND_DIRS[$i]}" 2>/dev/null | cut -f1)
            echo "  $((i+1))) ${FOUND_DIRS[$i]} (${dir_size})"
        done
        echo "  $((${#FOUND_DIRS[@]}+1))) Enter custom directory"

        read -p "$(echo -e ${GREEN}Select directory [1-$((${#FOUND_DIRS[@]}+1))]: ${NC})" dir_choice

        if [ "$dir_choice" -ge 1 ] && [ "$dir_choice" -le ${#FOUND_DIRS[@]} ] 2>/dev/null; then
            BUILD_DIR="${FOUND_DIRS[$((dir_choice-1))]}"
            echo -e "${GREEN}✓ Selected: $BUILD_DIR${NC}"
        elif [ "$dir_choice" = "$((${#FOUND_DIRS[@]}+1))" ]; then
            read -p "$(echo -e ${GREEN}Enter build directory path: ${NC})" BUILD_DIR
        else
            echo -e "${YELLOW}Invalid selection, please enter directory manually${NC}"
            read -p "$(echo -e ${GREEN}Enter build directory path: ${NC})" BUILD_DIR
        fi
    else
        echo -e "${YELLOW}No common build directories found.${NC}"
        echo "Common build directories include: build, dist, target, bin, out"
        read -p "$(echo -e ${GREEN}Enter your build directory path: ${NC})" BUILD_DIR
    fi

    # Validate the directory exists
    if [ ! -d "$BUILD_DIR" ]; then
        echo -e "${RED}ERROR: Directory '$BUILD_DIR' not found${NC}"
        echo "Please run your build command first"
        return 1
    fi

    BUILD_SIZE=$(du -sh "$BUILD_DIR" | cut -f1)
    echo -e "${GREEN}✓ Using build directory: $BUILD_DIR (${BUILD_SIZE})${NC}\n"

    export BUILD_DIR
    return 0
}

# Function to execute scan with consistent formatting
execute_scan() {
    local scan_cmd=$1

    echo -e "\n${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}Command to be executed:${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"

    # Create obfuscated version for display
    local obfuscated_token=$(obfuscate_token "$BLACKDUCK_API_TOKEN" 8)
    local display_cmd="${scan_cmd//$BLACKDUCK_API_TOKEN/$obfuscated_token}"

    # Display the command with obfuscated token and proper formatting
    echo -e "${YELLOW}$display_cmd${NC}" | sed 's/ --/\n    --/g' | sed 's/java -jar/java -jar/g'

    echo -e "\n${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}Key parameters explained:${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

    # Explain key parameters based on what's in the command
    if [[ "$scan_cmd" =~ "--detect.tools=DETECTOR" ]] && [[ "$scan_cmd" =~ "signature.scanner.disabled=true" ]]; then
        echo -e "${GREEN}--detect.tools=DETECTOR${NC}"
        echo "  → Runs package manager detection only"
        echo -e "${GREEN}--detect.blackduck.signature.scanner.disabled=true${NC}"
        echo "  → Disables signature scanning for faster results"
    elif [[ "$scan_cmd" =~ "--detect.tools=SIGNATURE_SCAN" ]] && [[ "$scan_cmd" =~ "detector.search.enabled=false" ]]; then
        echo -e "${GREEN}--detect.tools=SIGNATURE_SCAN${NC}"
        echo "  → Runs signature scanning only"
        echo -e "${GREEN}--detect.detector.search.enabled=false${NC}"
        echo "  → Disables package manager detection"
    elif [[ "$scan_cmd" =~ "--detect.tools=DETECTOR,SIGNATURE_SCAN" ]]; then
        echo -e "${GREEN}--detect.tools=DETECTOR,SIGNATURE_SCAN${NC}"
        echo "  → Runs both package manager detection AND signature scanning"
    elif [[ "$scan_cmd" =~ "--detect.tools=CONTAINER_SCAN" ]]; then
        echo -e "${GREEN}--detect.tools=CONTAINER_SCAN${NC}"
        echo "  → Analyzes Docker container layers"
        echo -e "${GREEN}--detect.container.scan.file.path${NC}"
        echo "  → Points to the saved container tar file"
    fi

    if [[ "$scan_cmd" =~ "--detect.npm.dependency.types.excluded=DEV" ]]; then
        echo -e "${GREEN}--detect.npm.dependency.types.excluded=DEV${NC}"
        echo "  → Excludes npm devDependencies for accuracy"
    fi

    if [[ "$scan_cmd" =~ "--detect.blackduck.signature.scanner.paths=" ]]; then
        echo -e "${GREEN}--detect.blackduck.signature.scanner.paths${NC}"
        echo "  → Limits signature scanning to specific directory"
    fi

    if [[ "$scan_cmd" =~ "--detect.excluded.directories=" ]]; then
        echo -e "${GREEN}--detect.excluded.directories${NC}"
        echo "  → Skips scanning these directories"
    fi

    echo -e "\n${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}Executing scan...${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"

    eval $scan_cmd

    if [ $? -eq 0 ]; then
        echo -e "\n${GREEN}✓ Scan complete${NC}"
    else
        echo -e "\n${YELLOW}⚠ Scan completed with warnings or errors${NC}"
    fi
}

# Function to print summary
print_summary() {
    echo -e "\n${CYAN}════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}Scan Complete!${NC}"
    echo -e "${CYAN}════════════════════════════════════════════════════════${NC}"
    echo ""
    echo -e "${BLUE}Next Steps:${NC}"
    echo "1. Check Black Duck web interface for results"
    echo "2. Review any policy violations"
    echo "3. Update vulnerable dependencies if needed"
    echo ""
}

# Function to detect binary files
detect_binary_files() {
    local found_patterns=()
    local example_files=()
    local binary_count=0

    echo -e "${CYAN}Scanning for binary files...${NC}"

    for pattern in "${BINARY_PATTERNS[@]}"; do
        # Use find to look for files matching the pattern, excluding common directories
        local files=$(find . -type f -name "$pattern" \
            -not -path "./node_modules/*" \
            -not -path "./.git/*" \
            -not -path "./vendor/*" \
            -not -path "./.idea/*" \
            -not -path "./.vscode/*" \
            -not -path "./venv/*" \
            -not -path "./.env/*" \
            2>/dev/null | head -5)

        if [ -n "$files" ]; then
            found_patterns+=("$pattern")
            # Get first example for display
            local first_file=$(echo "$files" | head -1)
            example_files+=("$(basename "$first_file")")
            # Count total files found
            local count=$(echo "$files" | wc -l)
            ((binary_count += count))
        fi
    done

    if [ ${#found_patterns[@]} -gt 0 ]; then
        FOUND_BINARIES=$(IFS=','; echo "${found_patterns[*]}")
        BINARY_EXAMPLES=$(IFS=', '; echo "${example_files[*]}")
        echo -e "${GREEN}✓ Found binary files:${NC} $binary_count files matching patterns"
        echo -e "${GREEN}  Patterns:${NC} ${found_patterns[*]}"
        echo -e "${GREEN}  Examples:${NC} ${BINARY_EXAMPLES}${NC}"
        return 0
    else
        echo -e "${YELLOW}No binary files detected in project${NC}"
        return 1
    fi
}

# Main script starts here
echo -e "${CYAN}╔══════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║   Black Duck SCA Scanner - Interactive Mode          ║${NC}"
echo -e "${CYAN}║            Learn While You Scan v2.3 (Secure)        ║${NC}"
echo -e "${CYAN}╚══════════════════════════════════════════════════════╝${NC}"
echo ""

# Check prerequisites
check_prerequisites

# Get project info
PROJECT_DATA=$(detect_project_info)
IFS='|' read -r DEFAULT_NAME DEFAULT_VERSION PROJECT_TYPE <<< "$PROJECT_DATA"

if [ -n "$DEFAULT_NAME" ] || [ -n "$DEFAULT_VERSION" ]; then
    echo -e "${CYAN}Detected project type: ${GREEN}${PROJECT_TYPE}${NC}"
fi

# Strategy Selection Menu
echo -e "\n${BLUE}Select scanning strategy:${NC}"
echo -e "${YELLOW}Accuracy: ★★★★ = Most accurate, ★★★ = Highly accurate, ★★ = Good, ★ = More false positives${NC}"
echo ""

echo -e "${GREEN}1) Production Build${NC} - What ships to customers (2-3 minutes) ${YELLOW}[★★★★ Accuracy]${NC}"
echo -e "   • Scans only your built artifacts (build/dist/target directory)"
echo -e "   • ${YELLOW}No dependency analysis${NC} - signatures only"
echo -e "   • Best for: Verifying production builds"
echo ""

echo -e "${GREEN}2) Dependencies Only${NC} - Fast, accurate dependency analysis (30-60 seconds) ${YELLOW}[★★★★ - ★★★ Accuracy]${NC}"
echo -e "   • Scans ${PROJECT_TYPE:-package manager} dependencies"
echo -e "   • ${YELLOW}Excludes devDependencies by default${NC}"
echo -e "   • Best for: Daily development, CI/CD pipelines"
echo ""

echo -e "${GREEN}3) Full Analysis${NC} - Dependencies + code signatures (3-5 minutes) ${YELLOW}[★★★ - ★★ Accuracy]${NC}"
echo -e "   • Scans both dependencies and your source code"
echo -e "   • May find additional OSS components not in package files"
echo -e "   • Best for: Pre-release checks, security audits"
echo ""

if [ "$DOCKER_AVAILABLE" = "true" ]; then
    echo -e "${GREEN}4) Container Scan${NC} - Analyze Docker containers (5-10 minutes per container) ${YELLOW}[★★★★ Accuracy]${NC}"
    echo -e "   • Scans Docker container images layer by layer"
    echo -e "   • Identifies OS packages, libraries, and vulnerabilities"
    echo -e "   • Best for: Container security assessment"
    echo -e "   • ${YELLOW}Requires BDSC license${NC}"
    echo ""

    read -p "$(echo -e ${GREEN}Select strategy \(1-4\) [default: 2]: ${NC})" STRATEGY
else
    read -p "$(echo -e ${GREEN}Select strategy \(1-3\) [default: 2]: ${NC})" STRATEGY
fi

STRATEGY=${STRATEGY:-2}
echo ""

# Base command for all scans
BASE_CMD="java -jar $DETECT_JAR"

# Initialize variables
FOUND_DIRS=($(detect_build_directories))

case $STRATEGY in
    1) # Production Build
        echo -e "${BLUE}=== Production Build Scan ===${NC}"
        echo -e "${YELLOW}Accuracy: ★★★★ (Most accurate - focused signature scan)${NC}"
        explain_scan "production"

        # Select build directory
        if ! select_build_directory "${FOUND_DIRS[@]}"; then
            exit 1
        fi

        get_project_info "-production" "$PROJECT_DATA"
        PROJECT_NAME_FOR_CONTAINERS="$PROJECT_NAME"

        # Build command
        SCAN_CMD="$BASE_CMD \
            --blackduck.url=$BLACKDUCK_URL \
            --blackduck.api.token=$BLACKDUCK_API_TOKEN \
            --blackduck.trust.cert=true \
            --detect.project.name=\"$PROJECT_NAME\" \
            --detect.project.description=\"This application was scanned with blackduck_scan_accuracy.sh and is not meant for pipeline, production, or enterprise scanning; this script is intended purely for educational purposes to illustrate the different results possible using different scanning strategies.\" \
            --detect.project.version.name=\"$PROJECT_VERSION\" \
            --detect.tools=SIGNATURE_SCAN \
            --detect.detector.search.enabled=false \
            --detect.blackduck.signature.scanner.paths=$BUILD_DIR \
            --detect.blackduck.signature.scanner.exclusion.patterns=\"*.map,*.log,*.cache,*cache*,BUILD_ID,*.tmp,*.temp,*.swp\""


        echo -e "\n${YELLOW}Ready to scan production build...${NC}"
        read -p "$(echo -e ${GREEN}Continue? \(y/n\) [default: y]: ${NC})" confirm
        confirm=${confirm:-y}

        if [ "$confirm" = "y" ]; then
            execute_scan "$SCAN_CMD"
        fi
        ;;

    2) # Dependencies Only
        echo -e "${BLUE}=== Dependencies Only Scan ===${NC}"
        explain_scan "dependencies"

        get_project_info "" "$PROJECT_DATA"
        PROJECT_NAME_FOR_CONTAINERS="$PROJECT_NAME"

        # Ask about dev dependencies
        echo ""
        read -p "$(echo -e ${GREEN}Include devDependencies? \(y/N\) [default: n]: ${NC})" include_dev
        include_dev=${include_dev:-n}

        if [ "$include_dev" = "y" ]; then
            echo -e "${CYAN}→ Including ALL dependencies${NC}"
            echo -e "${YELLOW}Accuracy: ★★★ (Good - includes development tools)${NC}"
        else
            echo -e "${YELLOW}→ Excluding devDependencies (recommended)${NC}"
            echo -e "${YELLOW}Accuracy: ★★★★ (Most accurate - production only)${NC}"
        fi

        DEV_FLAG=$(get_exclude_dev_flag "$PROJECT_TYPE" "$include_dev")

        # Build command
        SCAN_CMD="$BASE_CMD \
            --blackduck.url=$BLACKDUCK_URL \
            --blackduck.api.token=$BLACKDUCK_API_TOKEN \
            --blackduck.trust.cert=true \
            --detect.project.name=\"$PROJECT_NAME\" \
            --detect.project.description=\"This application was scanned with blackduck_scan_accuracy.sh and is not meant for pipeline, production, or enterprise scanning; this script is intended purely for educational purposes to illustrate the different results possible using different scanning strategies.\" \
            --detect.project.version.name=\"$PROJECT_VERSION\" \
            --detect.tools=DETECTOR \
            --detect.blackduck.signature.scanner.disabled=true \
            $DEV_FLAG"

        echo -e "\n${YELLOW}Ready to scan dependencies...${NC}"
        read -p "$(echo -e ${GREEN}Continue? \(y/n\) [default: y]: ${NC})" confirm
        confirm=${confirm:-y}

        if [ "$confirm" = "y" ]; then
            execute_scan "$SCAN_CMD"
        fi
        ;;

    3) # Full Analysis
        echo -e "${BLUE}=== Full Analysis Scan ===${NC}"
        explain_scan "full"

        get_project_info "" "$PROJECT_DATA"
        PROJECT_NAME_FOR_CONTAINERS="$PROJECT_NAME"

        # Ask what to scan
        echo ""
        echo -e "${YELLOW}What would you like to scan for signatures?${NC}"
        echo -e "1) Entire codebase ${YELLOW}[★★ Accuracy - more false positives]${NC}"
        echo "   • Scans all source files, tests, configs, etc."
        echo "   • May match common code patterns incorrectly"
        echo -e "2) Build/Production directory only ${YELLOW}[★★★ Accuracy - more focused]${NC}"
        echo "   • Scans only compiled/built artifacts"
        echo "   • Fewer false positives, clearer results"
        read -p "$(echo -e ${GREEN}Select \(1-2\) [default: 1]: ${NC})" scan_scope
        scan_scope=${scan_scope:-1}

        if [ "$scan_scope" = "2" ]; then
            # Select build directory
            if ! select_build_directory "${FOUND_DIRS[@]}"; then
                exit 1
            fi

            echo -e "${YELLOW}Accuracy: ★★★ (Highly accurate - focused scan)${NC}"
            SIGNATURE_PATH="--detect.blackduck.signature.scanner.paths=$BUILD_DIR"
            SIGNATURE_EXCLUSIONS="--detect.blackduck.signature.scanner.exclusion.patterns=\"*.map,*.log,*.cache,*cache*,BUILD_ID,*.tmp,*.temp,*.swp\""
        else
            echo -e "${YELLOW}Accuracy: ★★ (Good - some signature false positives possible)${NC}"
            SIGNATURE_PATH=""
            SIGNATURE_EXCLUSIONS="--detect.excluded.directories=.git,node_modules,vendor,.idea,.vscode,test,tests,spec,specs"
        fi

        # Ask about dev dependencies
        echo ""
        read -p "$(echo -e ${GREEN}Include devDependencies? \(y/N\) [default: n]: ${NC})" include_dev
        include_dev=${include_dev:-n}

        if [ "$include_dev" = "y" ]; then
            echo -e "${CYAN}→ Including ALL dependencies${NC}"
        else
            echo -e "${YELLOW}→ Excluding devDependencies (recommended)${NC}"
        fi

        DEV_FLAG=$(get_exclude_dev_flag "$PROJECT_TYPE" "$include_dev")

        # Build command
        SCAN_CMD="$BASE_CMD \
            --blackduck.url=$BLACKDUCK_URL \
            --blackduck.api.token=$BLACKDUCK_API_TOKEN \
            --blackduck.trust.cert=true \
            --detect.project.name=\"$PROJECT_NAME\" \
            --detect.project.description=\"This application was scanned with blackduck_scan_accuracy.sh and is not meant for pipeline, production, or enterprise scanning; this script is intended purely for educational purposes to illustrate the different results possible using different scanning strategies.\" \
            --detect.project.version.name=\"$PROJECT_VERSION\" \
            --detect.tools=DETECTOR,SIGNATURE_SCAN \
            $DEV_FLAG \
            $SIGNATURE_PATH \
            $SIGNATURE_EXCLUSIONS"

        echo -e "\n${YELLOW}This scan will take 3-5 minutes...${NC}"
        read -p "$(echo -e ${GREEN}Continue? \(y/n\) [default: y]: ${NC})" confirm
        confirm=${confirm:-y}

        if [ "$confirm" = "y" ]; then
            execute_scan "$SCAN_CMD"
        fi
        ;;

    4) # Container Scan
        if [ "$DOCKER_AVAILABLE" != "true" ]; then
            echo -e "${RED}Docker is not available. Please start Docker and try again.${NC}"
            exit 1
        fi

        echo -e "${BLUE}=== Container Scan ===${NC}"
        echo -e "${YELLOW}Accuracy: ★★★★ (Most accurate - full container analysis)${NC}"
        explain_scan "container"

        # Get base project name for container detection
        local temp_project_data=$PROJECT_DATA
        IFS='|' read -r temp_name temp_version temp_type <<< "$temp_project_data"
        if [ -z "$temp_name" ]; then
            read -p "$(echo -e ${GREEN}Enter project name for container detection: ${NC})" temp_name
        fi

        PROJECT_NAME_FOR_CONTAINERS="$temp_name"

        # Detect containers
        echo ""
        detect_containers "$temp_name"

        if [ -n "$CONTAINERS_FOUND" ]; then
            echo -e "\n${BLUE}Select containers to scan:${NC}"

            # Process each container (using ╬ as delimiter)
            IFS='╬' read -ra container_array <<< "$CONTAINERS_FOUND"
            for container_info in "${container_array[@]}"; do
                # Skip empty entries
                if [ -z "$container_info" ]; then
                    continue
                fi

                IFS='|' read -r id name image status <<< "$container_info"

                # Skip if we don't have valid data
                if [ -z "$name" ] || [ -z "$image" ] || [ -z "$id" ]; then
                    continue
                fi

                read -p "$(echo -e ${GREEN}Scan container \'$name\' \($image\)? \(Y/n\): ${NC})" scan_this
                scan_this=${scan_this:-y}

                if [[ "${scan_this,,}" =~ ^(y|yes|)$ ]]; then
                    scan_container "$id" "$name" "$image"
                else
                    echo -e "${YELLOW}Skipping container $name${NC}"
                fi
            done
        fi

        # Option to manually enter container
        echo ""
        read -p "$(echo -e ${GREEN}Enter additional container name/ID to scan \(or press Enter to skip\): ${NC})" manual_container

        if [ -n "$manual_container" ]; then
            # Get container info
            container_info=$(docker ps -a --filter "name=$manual_container" --format "{{.ID}}|{{.Names}}|{{.Image}}" | head -1)
            if [ -z "$container_info" ]; then
                container_info=$(docker ps -a --filter "id=$manual_container" --format "{{.ID}}|{{.Names}}|{{.Image}}" | head -1)
            fi

            if [ -n "$container_info" ]; then
                IFS='|' read -r id name image <<< "$container_info"
                if [ -z "$PROJECT_NAME_FOR_CONTAINERS" ]; then
                    PROJECT_NAME_FOR_CONTAINERS="$name"
                fi
                scan_container "$id" "$name" "$image"
            else
                echo -e "${RED}Container '$manual_container' not found${NC}"
            fi
        fi
        ;;

    *)
        echo -e "${RED}Invalid choice. Please select 1-$([[ "$DOCKER_AVAILABLE" = "true" ]] && echo "4" || echo "3").${NC}"
        exit 1
        ;;
esac

# After the main scan, check if we should offer container scanning
if [ "$STRATEGY" != "4" ] && [ "$DOCKER_AVAILABLE" = "true" ]; then
    echo ""

    # Detect containers based on project name if available
    if [ -n "$PROJECT_NAME_FOR_CONTAINERS" ]; then
        detect_containers "$PROJECT_NAME_FOR_CONTAINERS"

        if [ -n "$CONTAINERS_FOUND" ]; then
            echo -e "\n${CYAN}════════════════════════════════════════════════════════${NC}"
            echo -e "${YELLOW}CONTAINER SCAN OPPORTUNITY${NC}"
            echo -e "${CYAN}════════════════════════════════════════════════════════${NC}"

            echo -e "\n${YELLOW}Note: Container scanning requires:${NC}"
            echo -e "• Black Duck Secure Container (BDSC) license"
            echo -e "• Match as a Service (MaaS) enabled"
            echo -e "• Black Duck 2023.10.0 or greater"
            echo ""

            read -p "$(echo -e ${GREEN}Would you like to scan related containers? \(Y/n\): ${NC})" scan_containers_now
            scan_containers_now=${scan_containers_now:-y}

            if [[ "${scan_containers_now,,}" =~ ^(y|yes|)$ ]]; then
                echo -e "\n${BLUE}Select containers to scan:${NC}"

                # Process each container (using ╬ as delimiter)
                IFS='╬' read -ra container_array <<< "$CONTAINERS_FOUND"
                for container_info in "${container_array[@]}"; do
                    # Skip empty entries
                    if [ -z "$container_info" ]; then
                        continue
                    fi

                    IFS='|' read -r id name image status <<< "$container_info"

                    # Skip if we don't have valid data
                    if [ -z "$name" ] || [ -z "$image" ] || [ -z "$id" ]; then
                        continue
                    fi

                    read -p "$(echo -e ${GREEN}Scan container \'$name\' \($image\)? \(Y/n\): ${NC})" scan_this
                    scan_this=${scan_this:-y}

                    if [[ "${scan_this,,}" =~ ^(y|yes|)$ ]]; then
                        scan_container "$id" "$name" "$image"
                    else
                        echo -e "${YELLOW}Skipping container $name${NC}"
                    fi
                done
            fi
        fi
    fi
fi

# Print summary
print_summary

# Quick explanation of what to expect
echo -e "${CYAN}What to expect in Black Duck:${NC}"
case $STRATEGY in
    1)
        echo "• Components detected in your build artifacts"
        echo "• May show bundled/minified libraries"
        echo "• Won't show development dependencies"
        echo "• Good for compliance verification"
        ;;
    2)
        echo "• Component list matching your ${PROJECT_TYPE:-package manager} dependencies"
        echo "• License information for each component"
        echo "• Security vulnerabilities (if any)"
        echo "• Policy violations based on your org's rules"
        ;;
    3)
        echo "• Component list from ${PROJECT_TYPE:-package manager}, PLUS:"
        if [ "$scan_scope" = "2" ]; then
            echo "• Components found in build directory only"
            echo "• More accurate with fewer false positives"
            echo "• Shows what's actually bundled for production"
        else
            echo "• Additional components found via signatures"
            echo "• Possible false positives from signature matching"
            echo "• More comprehensive but may need filtering"
        fi
        ;;
    4)
        echo "• Complete layer-by-layer container analysis"
        echo "• OS packages and system libraries"
        echo "• Application dependencies in the container"
        echo "• Security vulnerabilities at all layers"
        echo "• Results appear under PROJECT_NAME/containers"
        ;;
esac

if [ -n "$CONTAINERS_FOUND" ] && [ "$STRATEGY" != "4" ]; then
    echo ""
    echo -e "${CYAN}Container results (if scanned) appear under:${NC}"
    echo "• ${PROJECT_NAME_FOR_CONTAINERS}/containers"
fi

echo ""
