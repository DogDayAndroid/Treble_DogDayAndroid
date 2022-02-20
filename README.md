# DogDayAndroid系统(GSI)

本系统基于[Pixel Experience GSI 项目](https://github.com/ponces/treble_build_pe)修改而来。

## 构建

> 在生成OTA更新文件过程中，请确保你的系统拥有 [jq](https://stedolan.github.io/jq/) 命令。

开始构建本镜像之前, 你需要对[Git与Repo](https://source.android.com/source/using-repo.html) 和 [如何构建GSI](https://github.com/phhusson/treble_experimentations/wiki/How-to-build-a-GSI%3F)有一定了解再继续。

+ 构建一个目录用于存放镜像源码
+ 克隆此仓库
+ 调用脚本进行构建

例如：
``` bash
# 创建目录并进入
mkdir pixel; cd pixel
# 克隆本项目
git clone https://gitee.com/DogDayAndroid/Treble_DogDayAndroid.git -b DogDayAndroid_twelve
# 执行构建脚本（初始化构建）
bash Treble_DogDayAndroid/build.sh
```

### 初始化构建成功后本地构建

有时由于本仓库的补丁稍滞后于`Pixel Experience`源码，因此同步后打补丁会出现一些错误。如果您不了解如何去修复这些错误，请在第一次成功运行`build.sh`并成功构建之后，通过本地构建脚本进行构建，这样可以避免源码更新带来的一些错误。
``` bash
# 执行本地构建脚本（不进行仓库同步和打补丁）
bash Treble_DogDayAndroid/build.sh
```

## 致谢
首先需要感谢本脚本的来源者，为本项目的自动化构建提供了极大帮助：
- [ponces](https://github.com/ponces)
  
其次是这些以某种方式帮助了这个项目而有所功劳的人：
- [Pixel Experience Team](https://download.pixelexperience.org/about)
- [phhusson](https://github.com/phhusson)
- [AndyYan](https://github.com/AndyCGYan)
- [eremitein](https://github.com/eremitein)
- [kdrag0n](https://github.com/kdrag0n)
