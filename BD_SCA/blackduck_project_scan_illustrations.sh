#!/bin/bash
#
# Script: blackduck_project_scan_illustrations.sh
# Version: v2.0.0
#
# Type: Unattended Demo
# Purpose: Demonstrate how different Black Duck scanning strategies impact 
#          component discovery and accuracy through 5-7 automated scan variations.
#
#          The majority of the script execution is meant to be "hands-off" meaning 
#          just simple y/n are enough to keep the script scanning.
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
# Usage: ./blackduck_project_scan_illustrations.sh
#        Script will run 5-7 different scans with only y/n prompts between each
#

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

# Binary file patterns
BINARY_PATTERNS=(
    "*.exe" "*.dll" "*.msi"           # Windows
    "*.so" "*.a" "*.deb" "*.rpm"      # Linux
    "*.dylib" "*.dmg"                 # macOS
    "*.jar" "*.war" "*.ear" "*.class" # Java
    "*.nupkg"                         # .NET packages
    "*.pyc" "*.pyo" "*.whl"           # Python
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
PROJECT_NAME=""
PROJECT_TYPE=""
BUILD_DIR=""
FOUND_BINARIES=""
BINARY_EXAMPLES=""
TOTAL_SCANS=5
DOCKER_AVAILABLE=false
CONTAINERS_FOUND=""

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
    
    echo -e "${CYAN}Scanning for related containers...${NC}"
    
    # Clean project name for matching (remove special chars, convert to lowercase)
    local clean_name=$(echo "$PROJECT_NAME" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9-]//g' | sed 's/-accuracy-demo$//')
    
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
            --detect.project.name="$PROJECT_NAME/containers" \
            --detect.project.version.name="$container_name" \
            --detect.project.description="Container scan for $container_name ($container_image) - This was scanned with blackduck_project_scan_illustrations.sh for educational purposes" \
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

# Function to check prerequisites
check_prerequisites() {
    local missing=0
    
    echo -e "${CYAN}Checking prerequisites...${NC}"
    
    if [ -z "$BLACKDUCK_URL" ]; then
        echo -e "${RED}✗ BLACKDUCK_URL not set${NC}"
        missing=1
    else
        echo -e "${GREEN}✓ BLACKDUCK_URL found${NC}"
    fi
    
    if [ -z "$BLACKDUCK_API_TOKEN" ]; then
        echo -e "${RED}✗ BLACKDUCK_API_TOKEN not set${NC}"
        missing=1
    else
        echo -e "${GREEN}✓ BLACKDUCK_API_TOKEN found${NC}"
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

# Function to auto-detect project information
detect_project_info() {
    if [ -f "package.json" ]; then
        PROJECT_NAME=$(grep '"name"' package.json | head -1 | cut -d'"' -f4 || echo "")
        PROJECT_TYPE="npm"
    elif [ -f "pom.xml" ]; then
        PROJECT_NAME=$(grep -m1 '<artifactId>' pom.xml | sed 's/.*<artifactId>\(.*\)<\/artifactId>.*/\1/' || echo "")
        PROJECT_TYPE="maven"
    elif [ -f "build.gradle" ] || [ -f "build.gradle.kts" ]; then
        PROJECT_NAME=$(grep "rootProject.name" settings.gradle* 2>/dev/null | cut -d"'" -f2 | cut -d'"' -f2 || echo "")
        PROJECT_TYPE="gradle"
    elif [ -f "requirements.txt" ] || [ -f "setup.py" ] || [ -f "Pipfile" ]; then
        PROJECT_NAME=$(basename "$PWD")
        PROJECT_TYPE="python"
    elif [ -f "go.mod" ]; then
        PROJECT_NAME=$(grep "module" go.mod | awk '{print $2}' | rev | cut -d'/' -f1 | rev || echo "")
        PROJECT_TYPE="go"
    elif [ -f "*.csproj" ] || [ -f "*.sln" ]; then
        PROJECT_NAME=$(basename "$PWD")
        PROJECT_TYPE="dotnet"
    else
        PROJECT_NAME=""
        PROJECT_TYPE="unknown"
    fi
    
    # Fallback to directory name if no project name found
    if [ -z "$PROJECT_NAME" ]; then
        PROJECT_NAME=$(basename "$PWD")
    fi
    
    # Clean project name for use in version strings
    PROJECT_NAME=$(echo "$PROJECT_NAME" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9-]/-/g')
}

# Function to detect build directories
detect_build_directories() {
    # JavaScript/TypeScript
    if [ -d ".next" ]; then
        BUILD_DIR=".next"
        return 0
    elif [ -d "build" ]; then
        BUILD_DIR="build"
        return 0
    elif [ -d "dist" ]; then
        BUILD_DIR="dist"
        return 0
    elif [ -d "out" ]; then
        BUILD_DIR="out"
        return 0
    elif [ -d ".nuxt" ]; then
        BUILD_DIR=".nuxt"
        return 0
    # Java
    elif [ -d "target" ]; then
        BUILD_DIR="target"
        return 0
    elif [ -d "target/classes" ]; then
        BUILD_DIR="target/classes"
        return 0
    # Python
    elif [ -d "_build" ]; then
        BUILD_DIR="_build"
        return 0
    # .NET
    elif [ -d "bin/Release" ]; then
        BUILD_DIR="bin/Release"
        return 0
    elif [ -d "bin/Debug" ]; then
        BUILD_DIR="bin/Debug"
        return 0
    elif [ -d "publish" ]; then
        BUILD_DIR="publish"
        return 0
    # Go
    elif [ -d "bin" ]; then
        BUILD_DIR="bin"
        return 0
    # Rust
    elif [ -d "target/release" ]; then
        BUILD_DIR="target/release"
        return 0
    elif [ -d "target/debug" ]; then
        BUILD_DIR="target/debug"
        return 0
    fi
    
    BUILD_DIR=""
    return 1
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
        TOTAL_SCANS=6
        return 0
    else
        echo -e "${YELLOW}No binary files detected in project${NC}"
        return 1
    fi
}

# Function to run a scan with clear output
run_accuracy_scan() {
    local scan_number=$1
    local version_name=$2
    local version_notes=$3
    local phase=$4
    local detect_command=$5
    local expected_result=$6
    
    echo -e "\n${CYAN}════════════════════════════════════════════════════════${NC}"
    echo -e "${YELLOW}CODE SCAN $scan_number of $TOTAL_SCANS${NC}"
    echo -e "${GREEN}Version:${NC} $version_name"
    echo -e "${GREEN}Notes:${NC} $version_notes"
    echo -e "${GREEN}Phase:${NC} $phase"
    echo -e "${GREEN}Expected:${NC} $expected_result"
    
    # Add reminder about containers if this is the last scan
    if [ "$scan_number" = "$TOTAL_SCANS" ] && [ "$DOCKER_AVAILABLE" = "true" ] && [ -n "$CONTAINERS_FOUND" ]; then
        local container_count=$(echo "$CONTAINERS_FOUND" | tr '╬' '\n' | grep -v '^$' | wc -l)
        echo -e "${CYAN}Note: Container scanning will be offered after this scan (${container_count} containers found)${NC}"
    fi
    
    echo -e "${CYAN}════════════════════════════════════════════════════════${NC}"
    
    read -p "$(echo -e ${GREEN}Run this scan? \(Y/n/q\) [Y=yes, n=skip, q=quit]: ${NC})" choice
    
    # Default to 'y' if user just hits enter
    choice=${choice:-y}
    
    case ${choice,,} in  # Convert to lowercase
        y|yes)
            echo -e "\n${BLUE}Executing scan...${NC}\n"
            eval $detect_command
            if [ $? -eq 0 ]; then
                echo -e "\n${GREEN}✓ Scan complete${NC}"
            else
                echo -e "\n${YELLOW}⚠ Scan completed with warnings or errors${NC}"
            fi
            ;;
        n|no|s|skip)
            echo -e "${YELLOW}Skipping this scan${NC}"
            ;;
        q|quit)
            echo -e "${RED}Exiting demonstration${NC}"
            print_summary
            exit 0
            ;;
        *)
            echo -e "${YELLOW}Invalid input. Treating as 'yes'${NC}"
            echo -e "\n${BLUE}Executing scan...${NC}\n"
            eval $detect_command
            ;;
    esac
}

# Function to print summary
print_summary() {
    echo -e "\n${CYAN}════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}Demonstration Complete!${NC}"
    echo -e "${CYAN}════════════════════════════════════════════════════════${NC}"
    echo ""
    echo "Check Black Duck for results under project: ${GREEN}${PROJECT_NAME}${NC}"
    if [ -n "$CONTAINERS_FOUND" ]; then
        echo "Container scans appear under: ${GREEN}${PROJECT_NAME}/containers${NC}"
    fi
    echo ""
    echo -e "${YELLOW}Expected patterns:${NC}"
    echo "• dev-pm-only-devdeps: Most components (includes test/build tools)"
    echo "• dev-pm-nodevdeps+signature: Fewer components (production only)"
    echo "• dev-snippet-matching: Different type of findings"
    echo "• prod scans: Least components (only shipped code)"
    if [ -n "$FOUND_BINARIES" ]; then
        echo "• binary-scan: Binary analysis results"
    fi
    if [ -n "$CONTAINERS_FOUND" ]; then
        local container_count=$(echo "$CONTAINERS_FOUND" | tr '╬' '\n' | grep -v '^$' | wc -l)
        echo "• container scans: Full layer-by-layer analysis (${container_count} containers found)"
    fi
    echo ""
    echo -e "${BLUE}Key Learning:${NC} More components found ≠ more actual risk"
    echo "Choose scan strategy based on what you need to measure!"
}

# Main script starts here
echo -e "${CYAN}╔══════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║   Black Duck Scanning Accuracy Comparison Demo       ║${NC}"
echo -e "${CYAN}║         See How Scan Types Impact Results            ║${NC}"
echo -e "${CYAN}╚══════════════════════════════════════════════════════╝${NC}"
echo ""

# Check prerequisites
check_prerequisites

# Detect project information
detect_project_info

# Only add suffix if not already present
if [[ ! "$PROJECT_NAME" =~ -accuracy-demo$ ]]; then
    PROJECT_NAME="${PROJECT_NAME}-accuracy-demo"
fi

echo -e "${BLUE}This demonstration will run different scans to show how${NC}"
echo -e "${BLUE}scanning strategies impact component discovery and accuracy.${NC}"
echo ""
echo -e "Detected project type: ${GREEN}${PROJECT_TYPE}${NC}"
echo -e "Project name for demo: ${GREEN}${PROJECT_NAME}${NC}"
echo -e "All results will appear in Black Duck under this project name."
echo ""

# Detect build directory
detect_build_directories
if [ -z "$BUILD_DIR" ]; then
    echo -e "${YELLOW}Note: No build directory found.${NC}"
    echo -e "${YELLOW}Scans 4 & 5 (production build scans) will be skipped.${NC}"
    echo -e "${YELLOW}To include them, run your build command first:${NC}"
    case $PROJECT_TYPE in
        npm)
            echo -e "${YELLOW}  npm run build${NC}"
            ;;
        maven)
            echo -e "${YELLOW}  mvn clean package${NC}"
            ;;
        gradle)
            echo -e "${YELLOW}  gradle build${NC}"
            ;;
        python)
            echo -e "${YELLOW}  python setup.py build${NC}"
            ;;
        go)
            echo -e "${YELLOW}  go build${NC}"
            ;;
        dotnet)
            echo -e "${YELLOW}  dotnet build -c Release${NC}"
            ;;
    esac
else
    BUILD_SIZE=$(du -sh "$BUILD_DIR" 2>/dev/null | cut -f1 || echo "unknown size")
    echo -e "${GREEN}Found build directory: ${BUILD_DIR} (${BUILD_SIZE})${NC}"
    echo -e "${GREEN}Production scans 4 & 5 will use this directory.${NC}"
fi

# Detect binary files
echo ""
detect_binary_files

# Detect containers
echo ""
detect_containers
echo ""

# Display demonstration overview
echo -e "${BLUE}Demonstration Overview:${NC}"
echo -e "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "${YELLOW}Phase 1: Code Scanning (${TOTAL_SCANS} scans)${NC}"
echo -e "  • Different strategies for scanning your application code"
echo -e "  • Compares accuracy and completeness of various approaches"

if [ "$DOCKER_AVAILABLE" = "true" ] && [ -n "$CONTAINERS_FOUND" ]; then
    local container_count=$(echo "$CONTAINERS_FOUND" | tr '╬' '\n' | wc -l)
    echo -e "\n${YELLOW}Phase 2: Container Scanning (optional)${NC}"
    echo -e "  • Analyzes Docker containers related to your project"
    echo -e "  • Scans OS packages, libraries, and container layers"
    echo -e "  • Creates sub-projects under ${PROJECT_NAME}/containers"
fi
echo -e "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

read -p "$(echo -e ${GREEN}Ready to start Phase 1: Code Scanning? \(Y/n\): ${NC})" start_demo
# Default to 'y' if user just hits enter
start_demo=${start_demo:-y}

if [[ ! "${start_demo,,}" =~ ^(y|yes|)$ ]]; then
    echo "Exiting demonstration."
    exit 0
fi

# Base command
BASE_CMD="java -jar $DETECT_JAR \
    --blackduck.url=$BLACKDUCK_URL \
    --blackduck.api.token=$BLACKDUCK_API_TOKEN \
    --blackduck.trust.cert=true \
    --detect.project.name=\"$PROJECT_NAME\" \
    --detect.project.description=\"This application was scanned with blackduck_project_scan_illustrations.sh and is not meant for pipeline, production, or enterprise scanning; this script is intended purely for educational purposes to illustrate the different results possible using different scanning strategies.\""

# Scan 1: Development with all dependencies
run_accuracy_scan \
    "1" \
    "dev-pm-only-devdeps-codebase" \
    "Package manager scan with development dependencies included (no signature scan)" \
    "DEVELOPMENT" \
    "$BASE_CMD \
        --detect.project.version.name=\"dev-pm-only-devdeps-codebase\" \
        --detect.project.version.phase=DEVELOPMENT \
        --detect.tools=DETECTOR \
        --detect.excluded.directories=.git,node_modules,vendor,.idea,.vscode \
        --detect.blackduck.signature.scanner.disabled=true" \
    "Highest component count - includes all dev tools"

# Scan 2: Development without devDeps + signatures
EXCLUDE_DEV_FLAG=""
case $PROJECT_TYPE in
    npm)
        EXCLUDE_DEV_FLAG="--detect.npm.dependency.types.excluded=DEV"
        ;;
    maven)
        EXCLUDE_DEV_FLAG="--detect.maven.excluded.scopes=test,provided"
        ;;
    gradle)
        EXCLUDE_DEV_FLAG="--detect.gradle.excluded.configurations=testCompile,testImplementation"
        ;;
    python)
        EXCLUDE_DEV_FLAG="--detect.pip.only.project.tree=true"
        ;;
esac

run_accuracy_scan \
    "2" \
    "dev-pm-nodevdeps+signature-codebase" \
    "Package manager scan excluding devDeps + signature scan of entire codebase" \
    "DEVELOPMENT" \
    "$BASE_CMD \
        --detect.project.version.name=\"dev-pm-nodevdeps+signature-codebase\" \
        --detect.project.version.phase=DEVELOPMENT \
        --detect.tools=DETECTOR,SIGNATURE_SCAN \
        --detect.excluded.directories=.git,node_modules,vendor,.idea,.vscode,test,tests,spec,specs \
        $EXCLUDE_DEV_FLAG" \
    "More accurate - production deps only + file signatures"

# Scan 3: Snippet matching only
run_accuracy_scan \
    "3" \
    "dev-snippet-matching-only" \
    "Snippet scan only with no other scan types" \
    "DEVELOPMENT" \
    "$BASE_CMD \
        --detect.project.version.name=\"dev-snippet-matching-only\" \
        --detect.project.version.phase=DEVELOPMENT \
        --detect.tools.excluded=DETECTOR,SIGNATURE_SCAN \
        --detect.blackduck.signature.scanner.snippet.matching=SNIPPET_MATCHING \
        --detect.excluded.directories=.git,node_modules,vendor,.idea,.vscode" \
    "Different results - finds code similarities"

# Scan 4: Production build analysis
if [ -n "$BUILD_DIR" ] && [ -d "$BUILD_DIR" ]; then
    # Save current directory
    ORIGINAL_DIR=$(pwd)
    
    run_accuracy_scan \
        "4" \
        "prod-build-analysis" \
        "Full analysis from within build directory (what actually ships)" \
        "RELEASED" \
        "cd $BUILD_DIR && java -jar $DETECT_JAR \
            --blackduck.url=$BLACKDUCK_URL \
            --blackduck.api.token=$BLACKDUCK_API_TOKEN \
            --blackduck.trust.cert=true \
            --detect.project.name=\"$PROJECT_NAME\" \
            --detect.project.description=\"This application was scanned with blackduck_project_scan_illustrations.sh and is not meant for pipeline, production, or enterprise scanning; this script is intended purely for educational purposes to illustrate the different results possible using different scanning strategies.\" \
            --detect.project.version.name=\"prod-build-analysis\" \
            --detect.project.version.phase=RELEASED \
            --detect.tools=DETECTOR,SIGNATURE_SCAN \
            --detect.source.path=. \
            --detect.accuracy.required=NONE \
            --detect.project.code.location.name=\"$PROJECT_NAME-prod-build-analysis\" && cd \"$ORIGINAL_DIR\"" \
        "Analyzes only what's in the build directory - true production view"
else
    echo -e "\n${YELLOW}Skipping Scan 4 - no build directory found${NC}"
fi

# Scan 5: Production signature scan only
if [ -n "$BUILD_DIR" ] && [ -d "$BUILD_DIR" ]; then
    run_accuracy_scan \
        "5" \
        "prod-signature-build-dir" \
        "Signature scan of build directory only (no dependency analysis)" \
        "RELEASED" \
        "$BASE_CMD \
            --detect.project.version.name=\"prod-signature-build-dir\" \
            --detect.project.version.phase=RELEASED \
            --detect.tools=SIGNATURE_SCAN \
            --detect.detector.search.enabled=false \
            --detect.blackduck.signature.scanner.paths=$BUILD_DIR" \
        "Minimal results - bundled/minified code only"
else
    echo -e "\n${YELLOW}Skipping Scan 5 - no build directory found${NC}"
fi

# Scan 6: Binary scan (if binaries detected)
if [ -n "$FOUND_BINARIES" ]; then
    echo -e "\n${CYAN}Binary files detected! Adding binary scan to demonstration.${NC}"
    
    run_accuracy_scan \
        "6" \
        "binary-analysis-scan" \
        "Binary analysis scan for compiled artifacts (Examples: $BINARY_EXAMPLES)" \
        "RELEASED" \
        "$BASE_CMD \
            --detect.project.version.name=\"binary-analysis-scan\" \
            --detect.project.version.phase=RELEASED \
            --detect.tools=BINARY_SCAN \
            --detect.binary.scan.file.name.patterns=\"$FOUND_BINARIES\" \
            --detect.excluded.directories=.git,node_modules,vendor,.idea,.vscode" \
        "Binary components - analyzing compiled/packaged artifacts"
else
    echo -e "\n${YELLOW}No binary files detected - skipping binary scan${NC}"
fi

# Container scanning section
if [ "$DOCKER_AVAILABLE" = "true" ] && [ -n "$CONTAINERS_FOUND" ]; then
    echo -e "\n${CYAN}════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}PHASE 1 COMPLETE: CODE SCANNING FINISHED!${NC}"
    echo -e "${CYAN}════════════════════════════════════════════════════════${NC}"
    echo -e "\n${BLUE}Moving to Phase 2: Container Scanning${NC}"
    echo -e "${BLUE}Container scans analyze the full software stack in your containers${NC}"
    echo -e "${BLUE}including OS packages, libraries, and dependencies.${NC}"
    
    echo -e "\n${CYAN}════════════════════════════════════════════════════════${NC}"
    echo -e "${YELLOW}CONTAINER SCAN OPPORTUNITY${NC}"
    echo -e "${CYAN}════════════════════════════════════════════════════════${NC}"
    
    echo -e "\n${YELLOW}Note: Container scanning requires:${NC}"
    echo -e "• Black Duck Secure Container (BDSC) license"
    echo -e "• Match as a Service (MaaS) enabled"
    echo -e "• Black Duck 2023.10.0 or greater"
    echo ""
    
    read -p "$(echo -e ${GREEN}Would you like to proceed with Phase 2: Container Scanning? \(Y/n\): ${NC})" scan_containers
    scan_containers=${scan_containers:-y}
    
    if [[ "${scan_containers,,}" =~ ^(y|yes|)$ ]]; then
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
                scan_container "$id" "$name" "$image"
            else
                echo -e "${RED}Container '$manual_container' not found${NC}"
            fi
        fi
    else
        echo -e "${YELLOW}Skipping Phase 2: Container Scanning${NC}"
    fi
else
    if [ "$DOCKER_AVAILABLE" != "true" ]; then
        echo -e "\n${YELLOW}Docker not available - Phase 2: Container Scanning not available${NC}"
    elif [ -z "$CONTAINERS_FOUND" ]; then
        echo -e "\n${YELLOW}No related containers found - Phase 2: Container Scanning not applicable${NC}"
    fi
fi

# Print summary
print_summary
