echo "# synergy4-docker" >> README.md
git init
git add README.md
git add Dockerfile
git commit -m "first commit"
git branch -M main
git remote add origin https://github.com/amirren/synergy4-docker.git
git push -u origin main