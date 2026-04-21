#!/bin/bash

# Exit immediately if a command exits with a non-zero status
set -e

# Define colors for better output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${BLUE}============================================================${NC}"
echo -e "${BLUE}   Starting Automated Publish Pipeline for Respondo${NC}"
echo -e "${BLUE}============================================================${NC}"

# 1. Clean old builds
echo -e "\n${BLUE}Step 1: Cleaning old gem files...${NC}"
bundle exec rake publish:clean

# 2. Run Specs
echo -e "\n${BLUE}Step 2: Running RSpec suite...${NC}"
if bundle exec rake publish:spec; then
    echo -e "${GREEN}✅ Specs passed!${NC}"
else
    echo -e "${RED}❌ Specs failed. Aborting.${NC}"
    exit 1
fi

# 3. Build Gem
echo -e "\n${BLUE}Step 3: Building Gem...${NC}"
bundle exec rake publish:build

# 4. Push to RubyGems
echo -e "\n${BLUE}Step 4: Pushing to RubyGems...${NC}"
# Logic check: only push if the gem file was actually created
if [ -f *.gem ]; then
    bundle exec rake publish:push
else
    echo -e "${RED}❌ Gem file not found. Build might have failed.${NC}"
    exit 1
fi

echo -e "\n${GREEN}============================================================${NC}"
echo -e "${GREEN}🎉 Automation Complete! Respondo is now live.${NC}"
echo -e "${GREEN}============================================================${NC}"