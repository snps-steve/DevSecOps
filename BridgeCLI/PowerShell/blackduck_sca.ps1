# Black Duck SCA Integration using Bridge CLI
# Ensure Bridge CLI is installed and configured

# Set environment variables
$env:BRIDGE_API_TOKEN = "your_black_duck_api_token"
$env:BRIDGE_URL = "https://your_black_duck_instance_url"

# Run Bridge CLI for SCA scan
bridge scan --type blackduck --project "YourProjectName" --version "1.0.0" --source "path/to/source"
