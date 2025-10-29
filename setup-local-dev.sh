#!/bin/bash

# Friendle Local Development Setup Script
# This script sets up a local Supabase environment for offline testing

set -e  # Exit on error

echo "🚀 Friendle Local Development Setup"
echo "===================================="
echo ""

# Check if Docker is running
if ! docker info > /dev/null 2>&1; then
    echo "❌ Error: Docker is not running"
    echo "Please start Docker Desktop and try again"
    exit 1
fi

echo "✅ Docker is running"

# Check if Supabase CLI is installed
if ! command -v supabase &> /dev/null; then
    echo "📦 Installing Supabase CLI..."
    npm install -g supabase
else
    echo "✅ Supabase CLI is already installed"
fi

# Initialize Supabase if not already done
if [ ! -d "supabase" ]; then
    echo "🔧 Initializing Supabase project..."
    supabase init
else
    echo "✅ Supabase project already initialized"
fi

# Create migrations directory and copy migration files
echo "📝 Setting up migrations..."
mkdir -p supabase/migrations

# Copy all MIGRATION_*.sql files to migrations directory
if ls MIGRATION_*.sql 1> /dev/null 2>&1; then
    for file in MIGRATION_*.sql; do
        # Extract timestamp or use sequential numbering
        filename=$(basename "$file")
        timestamp=$(date +%Y%m%d%H%M%S)
        # Remove MIGRATION_ prefix and add timestamp
        new_name="${timestamp}_${filename#MIGRATION_}"
        cp "$file" "supabase/migrations/$new_name"
        echo "  Copied: $filename -> $new_name"
    done
    echo "✅ Migrations copied"
else
    echo "⚠️  No MIGRATION_*.sql files found"
fi

# Start Supabase
echo ""
echo "🚀 Starting local Supabase..."
echo "This may take a few minutes on first run..."
echo ""

supabase start

echo ""
echo "✅ Local Supabase is running!"
echo ""
echo "📋 Save these credentials:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Get local credentials
LOCAL_ANON_KEY=$(supabase status | grep "anon key:" | awk '{print $3}')
LOCAL_SERVICE_KEY=$(supabase status | grep "service_role key:" | awk '{print $3}')

echo "API URL:         http://localhost:54321"
echo "Studio URL:      http://localhost:54323"
echo "DB URL:          postgresql://postgres:postgres@localhost:54322/postgres"
echo ""
echo "Anon Key:        $LOCAL_ANON_KEY"
echo "Service Role:    $LOCAL_SERVICE_KEY"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Create local environment config file
echo ""
echo "📝 Creating local environment configuration..."

cat > .env.local << EOF
# Local Supabase Configuration
# Generated on $(date)

SUPABASE_URL=http://localhost:54321
SUPABASE_ANON_KEY=$LOCAL_ANON_KEY
SUPABASE_SERVICE_ROLE_KEY=$LOCAL_SERVICE_KEY

# Database
DATABASE_URL=postgresql://postgres:postgres@localhost:54322/postgres

# OneSignal (use test keys for local development)
ONESIGNAL_APP_ID=67c70940-dc92-4d95-9072-503b2f5d84c8
ONESIGNAL_REST_API_KEY=your-test-key-here
EOF

echo "✅ Created .env.local with your credentials"

# Create index-local.html
echo ""
echo "📝 Creating index-local.html for local testing..."

if [ -f "index.html" ]; then
    cp index.html index-local.html

    # Replace Supabase URL and key in index-local.html
    # Note: This is a basic replacement, may need manual adjustment
    sed -i.bak "s|https://kxsewkjbhxtfqbytftbu.supabase.co|http://localhost:54321|g" index-local.html

    echo "✅ Created index-local.html"
    echo "⚠️  Please manually update the SUPABASE_ANON_KEY in index-local.html"
    echo "   Replace with: $LOCAL_ANON_KEY"
else
    echo "⚠️  index.html not found, skipping index-local.html creation"
fi

# Apply migrations
echo ""
echo "🔄 Applying migrations to local database..."
supabase db reset

echo ""
echo "✅ Setup complete!"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🎯 Next Steps:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "1. Update index-local.html with local Supabase credentials"
echo ""
echo "2. Start a local web server:"
echo "   python3 -m http.server 8000"
echo ""
echo "3. Open in browser:"
echo "   http://localhost:8000/index-local.html"
echo ""
echo "4. Access Supabase Studio:"
echo "   http://localhost:54323"
echo ""
echo "5. Deploy Edge Functions:"
echo "   supabase functions deploy event-reminders --no-verify-jwt"
echo "   supabase functions deploy inactivity-cleanup --no-verify-jwt"
echo "   supabase functions deploy send-notification"
echo "   supabase functions deploy stay-interested"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📚 Documentation:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Read LOCAL_DEVELOPMENT_GUIDE.md for detailed instructions"
echo ""
echo "Useful commands:"
echo "  supabase status      - Check running services"
echo "  supabase stop        - Stop local Supabase"
echo "  supabase db reset    - Reset database and re-run migrations"
echo "  supabase logs        - View logs"
echo ""
echo "Happy coding! 🎉"
