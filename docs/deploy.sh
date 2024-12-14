#!/bin/bash

# Configuration
DOMAIN="rmf.lol"  # Your Porkbun domain
DEPLOY_DIR="docs"

# Check if files exist
if [ ! -f "$DEPLOY_DIR/index.html" ]; then
    echo "Error: index.html not found in $DEPLOY_DIR"
    exit 1
fi

# Create .htaccess for clean URLs and caching
cat > "$DEPLOY_DIR/.htaccess" << EOL
# Enable rewriting
RewriteEngine On

# Handle HTTPS redirection
RewriteCond %{HTTPS} off
RewriteRule ^(.*)$ https://%{HTTP_HOST}%{REQUEST_URI} [L,R=301]

# Cache control
<IfModule mod_expires.c>
    ExpiresActive On
    ExpiresByType image/jpg "access plus 1 year"
    ExpiresByType image/jpeg "access plus 1 year"
    ExpiresByType image/gif "access plus 1 year"
    ExpiresByType image/png "access plus 1 year"
    ExpiresByType image/svg+xml "access plus 1 year"
    ExpiresByType text/css "access plus 1 month"
    ExpiresByType application/javascript "access plus 1 month"
</IfModule>

# Compression
<IfModule mod_deflate.c>
    AddOutputFilterByType DEFLATE text/plain
    AddOutputFilterByType DEFLATE text/html
    AddOutputFilterByType DEFLATE text/xml
    AddOutputFilterByType DEFLATE text/css
    AddOutputFilterByType DEFLATE application/xml
    AddOutputFilterByType DEFLATE application/xhtml+xml
    AddOutputFilterByType DEFLATE application/javascript
    AddOutputFilterByType DEFLATE application/x-javascript
</IfModule>
EOL

echo "Website files are ready for deployment!"
echo ""
echo "To deploy to rmf.lol:"
echo "1. Log in to your Porkbun account"
echo "2. Go to the domain management page for rmf.lol"
echo "3. Click on 'Website' or 'Hosting'"
echo "4. Enable web hosting if not already enabled"
echo "5. Upload the contents of the 'docs' directory to your web hosting space"
echo ""
echo "Note: Make sure to update the App Store link in index.html once your app is published" 