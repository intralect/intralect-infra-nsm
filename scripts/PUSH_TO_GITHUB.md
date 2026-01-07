# 📤 Push V5 Scripts to GitHub

Follow these steps to push your V5 production scripts to GitHub.

---

## Step 1: Create GitHub Repository

1. Go to https://github.com/new
2. Repository name: `v5-production-stack` (or your choice)
3. Description: `Production Mautic + n8n + Strapi AI-Enhanced Stack`
4. **Important:** Select **Private** (contains sensitive configs)
5. **DO NOT** initialize with README, .gitignore, or license
6. Click "Create repository"

---

## Step 2: Initialize Git Repository (On Server)

```bash
cd /root/scripts

# Initialize git
git init

# Add all files
git add .

# Create first commit
git commit -m "Initial commit: V5 production stack with unified manager"

# Rename branch to main
git branch -M main
```

---

## Step 3: Connect to GitHub

Replace `YOUR-USERNAME` and `YOUR-REPO-NAME` with your actual values:

```bash
# Add remote repository
git remote add origin https://github.com/YOUR-USERNAME/YOUR-REPO-NAME.git

# Push to GitHub
git push -u origin main
```

**Note:** You'll be prompted for your GitHub credentials.

### Using Personal Access Token (Recommended)

If you have 2FA enabled:
1. Go to https://github.com/settings/tokens
2. Click "Generate new token" → "Generate new token (classic)"
3. Give it a name: "V5 Production Scripts"
4. Select scopes: `repo` (full control)
5. Click "Generate token"
6. **Copy the token** (you won't see it again!)

Then use the token as password when pushing:
```bash
Username: YOUR-USERNAME
Password: ghp_xxxxxxxxxxxxxxxxxxxx  # Your token
```

---

## Step 4: Verify Upload

Visit your repository:
```
https://github.com/YOUR-USERNAME/YOUR-REPO-NAME
```

You should see:
- ✅ All scripts (`.sh` files)
- ✅ All documentation (`.md` files)
- ✅ `.gitignore` file
- ❌ NO `.env` files (excluded by .gitignore)
- ❌ NO backup files (excluded by .gitignore)

---

## Step 5: Add README to GitHub

```bash
cd /root/scripts

# Copy the GitHub README as main README
cp GITHUB_README.md README.md

# Commit and push
git add README.md
git commit -m "Add comprehensive README for GitHub"
git push
```

---

## 🔄 Future Updates

Whenever you make changes:

```bash
cd /root/scripts

# Check what changed
git status

# Add changes
git add .

# Commit with message
git commit -m "Description of what you changed"

# Push to GitHub
git push
```

---

## 📦 What Gets Uploaded

### ✅ Included (Safe to Share)
- Scripts: `*.sh`
- Documentation: `*.md`
- Config: `.gitignore`

### ❌ Excluded (Sensitive Data)
- Environment files: `.env`
- S3 config: `.s3-config`
- Backups: `*.tar.gz`, `*.sql`
- Logs: `*.log`
- Project directories: `mautic-n8n-stack*/`

The `.gitignore` file ensures sensitive data **never** gets uploaded.

---

## 🔒 Security Checklist

Before pushing, verify:

```bash
# Check what will be committed
git status

# View .gitignore to confirm exclusions
cat .gitignore

# Ensure .env is NOT staged
git ls-files | grep -E "\.env|password|secret|key" || echo "✅ No secrets found"
```

If you see any `.env` or password files, **DO NOT PUSH**.

---

## 🌐 Clone on Another Server

To deploy on a new server:

```bash
# Clone repository
git clone https://github.com/YOUR-USERNAME/YOUR-REPO-NAME.git
cd YOUR-REPO-NAME

# Make scripts executable
chmod +x *.sh

# Run unified manager
./v5_manager.sh
```

---

## 🎯 Repository Structure on GitHub

```
YOUR-REPO-NAME/
├── README.md                      ← GitHub README
├── .gitignore                     ← Excludes sensitive files
├── v5_manager.sh                  ← Unified interface ⭐
├── migrate_v4_to_v5.sh
├── update_n8n.sh
├── backup_now.sh
├── download_backup.sh
├── setup_resource_alerts.sh
├── QUICK_START.md
├── V5_MIGRATION_GUIDE.md
├── MAUTIC_CONFIG_REFERENCE.md
├── PRODUCTION_DEPLOYMENT_PLAN.md
└── archive/
    └── (old scripts)
```

---

## 💡 Tips

### Make Repository Public (Optional)
If you want to share with others:
1. Go to repository Settings
2. Scroll to "Danger Zone"
3. Click "Change visibility"
4. Select "Public"

**Only do this if there are NO secrets in the code!**

### Add License
```bash
cd /root/scripts

# Create MIT license
cat > LICENSE << 'EOF'
MIT License

Copyright (c) 2026 Your Name

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
EOF

git add LICENSE
git commit -m "Add MIT license"
git push
```

### Add Topics/Tags
On GitHub repository page:
1. Click "⚙️" next to "About"
2. Add topics:
   - `mautic`
   - `n8n`
   - `strapi`
   - `docker`
   - `ai-content-generation`
   - `marketing-automation`
   - `production-ready`
3. Save changes

---

## ✅ Verification

After pushing, confirm:
- [ ] Repository created on GitHub
- [ ] All scripts uploaded
- [ ] Documentation visible
- [ ] .gitignore working (no .env files visible)
- [ ] README displays correctly
- [ ] Repository is Private (or Public if intended)

---

**Ready to push to GitHub!** 🚀

Start with Step 1 above.
