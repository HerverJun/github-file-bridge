# GitHub 文件中转站

用公开 GitHub 仓库在外网与能访问 GitHub 的内网电脑之间中转文件。内网下载不需要登录。

## 网页上传与下载

1. 在外网电脑打开本仓库，进入 `files` 目录。
2. 点 **Add file → Upload files**，选择文件，填写说明并提交。
3. 在内网电脑直接打开仓库，无需登录 GitHub。
4. 点击所需文件，再点击 **Download raw file** 下载。下载整个仓库可用 **Code → Download ZIP**。

网页上传单个文件不得超过 25 MiB。大文件可先拆成每份 20 MiB 的分卷压缩包，将所有分卷上传到同一目录；下载全部分卷后再解压。

## Git 上传

安装 Git 后，可先克隆仓库，把文件复制到 `files`，然后提交和推送：

```powershell
git clone https://github.com/HerverJun/github-file-bridge.git
cd github-file-bridge
# 将待中转文件放入 files 目录
git add files
git commit -m "上传中转文件"
git push
```

另一台已经克隆的电脑用 `git pull` 获取新文件。Git 常规推送的单个文件上限为 100 MiB；超过 50 MiB 会触发警告。优先使用小文件或分卷。

## 使用说明

- 仓库为公开，任何人均可查看和下载文件及提交历史；上传仍需要账号写入权限。只中转允许公开的资料，账号密码、令牌等不要放入仓库。
- 文件实际下载可能跳转到 `raw.githubusercontent.com`、`codeload.github.com` 等域名。应先用一个小文件在内网试传、试下载，确认网络允许；能打开 github.com 不一定能下载全部文件。
- 暂不使用 Git LFS、Release 附件或外部图床，以减少额外域名和流量配额依赖。
- 删除文件后旧内容仍可能存在于 Git 历史，仓库不会因此立即变小。它适合临时中转，不适合作为无限容量网盘；长期堆积会让克隆和下载越来越慢。
- 本机使用时请把克隆、下载和临时文件放在 F 盘的项目目录中。
