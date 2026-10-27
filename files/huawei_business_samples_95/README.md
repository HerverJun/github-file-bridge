# 华为业务样例 ZIP

原文件：`huawei_business_samples_95.zip`，212,066,296 字节（约 202 MiB）。由于超过 GitHub 单文件 100 MiB 上限，按原始字节拆成 3 个分卷。仓库公开，下载无需登录。

## 下载

请把下列 3 个分卷下载到同一文件夹，保留 `.001`、`.002`、`.003` 文件名：

1. [分卷 001（90 MiB）](https://raw.githubusercontent.com/HerverJun/github-file-bridge/main/files/huawei_business_samples_95/huawei_business_samples_95.zip.001)
2. [分卷 002（90 MiB）](https://raw.githubusercontent.com/HerverJun/github-file-bridge/main/files/huawei_business_samples_95/huawei_business_samples_95.zip.002)
3. [分卷 003（约 22.2 MiB）](https://raw.githubusercontent.com/HerverJun/github-file-bridge/main/files/huawei_business_samples_95/huawei_business_samples_95.zip.003)

也可以点击本目录内的分卷文件，再点击 **Download raw file** 下载。如果网络不允许 raw 下载域名，可尝试仓库首页 **Code → Download ZIP**，解压后进入本目录。

## Windows 合并

在保存分卷的文件夹打开命令提示符（CMD），执行：

```bat
copy /b huawei_business_samples_95.zip.001+huawei_business_samples_95.zip.002+huawei_business_samples_95.zip.003 huawei_business_samples_95.zip
```

如果使用 PowerShell，执行：

```powershell
cmd /c "copy /b huawei_business_samples_95.zip.001+huawei_business_samples_95.zip.002+huawei_business_samples_95.zip.003 huawei_business_samples_95.zip"
```

合并后正常解压 `huawei_business_samples_95.zip`。不要只下载其中一卷，或把各卷分别当成完整 ZIP 解压。

## 完整性校验（可选）

```powershell
Get-FileHash .\huawei_business_samples_95.zip -Algorithm SHA256
```

原始 ZIP 的 SHA256：

```text
EE7E787254EC53F834BD35B433B8AD4DCF3F7CFFA4CB7939A1EBB62DC06AAAE7
```

上传前已按顺序读取全部分卷，确认还原内容与原文件一致。
