#!/bin/bash
VERSION=$(whiptail --inputbox --title "DogDayAndroid源码自动构建机器人"  "输入构建版本号\N点击<是>开始进行构建\n参考:github.com/ponces/treble_build_pe\n编写:easternDay" 10 60 "V001" 3>&1 1>&2 2>&3)
echo $VERSION
if [ $? ]; then
    if [ “$VERSION” = “” ]; then
        VERSION=“V001”
    fi
   echo “版本号：” $VERSION
else
    exit
fi

# 出错提示
set -eE
trap '(\
echo ;\
echo \!\!\! 脚本执行期间发生错误；\
echo \!\!\! 请检查控制台输出是否存在错误同步，；\
echo \!\!\! 补丁应用失败等。；\
echo \
)' ERR

# 开始记录时间
START=`date +%s`
BUILD_DATE="$(date +%Y%m%d)"
# 设置不检查API
WITHOUT_CHECK_API=true
# 设置一些目录参数，下面会用到
BL=$PWD/Treble_DogDayAndroid
BD=$PWD/../builds

# 如果不存在.repo目录则创建
if [ ! -d .repo ]
then
    echo "#####################################"
    echo "初始化<Pixel Experience 12>的 repo 仓库"
    repo init -u https://github.com/PixelExperience/manifest -b twelve
    echo ""

    echo "复制GSI所需文件"
    mkdir -p .repo/local_manifests
    cp $BL/manifest.xml .repo/local_manifests/pixel.xml
    echo "#####################################"
    echo ""
fi

# 提示是否需要进行代码拉取
if (whiptail --title "是否同步" --yesno "此选项决定你是否进行本地代码同步拉取和补丁的修复。\n如果你是第一次运行请选择<YES>。" 10 60) then
    echo "#####################################"
    echo "同步仓库中……"
    repo sync -c --force-sync --no-clone-bundle --no-tags -j$(nproc --all)
    echo "#####################################"
    echo ""

    echo "#####################################"
    echo "[1] 设置准备环境"
    source build/envsetup.sh &> /dev/null
    mkdir -p $BD
    echo ""

    echo "[2] 应用必备补丁"
    bash $BL/apply-patches.sh $BL prerequisite
    echo ""

    echo "[3] 应用PHH补丁"
    cd device/phh/treble
    cp $BL/pe.mk .
    bash generate.sh pe
    cd ../../..
    bash $BL/apply-patches.sh $BL phh
    echo ""

    echo "[4] 应用个人补丁"
    bash $BL/apply-patches.sh $BL personal
    echo ""

    echo "[5] 应用CN修复补丁"
    bash $BL/apply-patches.sh $BL EasternDay
    echo ""

    echo "[5] 增加个人使用的系统应用"
    #mkdir -p packages/apps/TrebleCheck_App
    #cp -rf $BL/app/* packages/apps/
    echo "#####################################"
    echo ""
else
    echo "#####################################"
    echo "跳过源码拉取和打补丁过程"
    echo "#####################################"
    echo "设置准备环境中……"
    source build/envsetup.sh &> /dev/null
    mkdir -p $BD
    echo "#####################################"
    echo ""
fi

buildTrebleApp() {
    echo "#####################################"
    echo "构建Treble App中……"
    cd treble_app
    bash build.sh release
    cp TrebleApp.apk ../vendor/hardware_overlay/TrebleApp/app.apk
    cd ..
    echo "#####################################"
    echo ""
}

buildRegularVariant() {
    echo "#####################################"
    echo "构建Variant镜像中……"
    lunch ${1}-userdebug
    make installclean
    make -j$(nproc --all) systemimage
    make vndk-test-sepolicy
    mv $OUT/system.img $BD/system-$1.img
    echo "#####################################"
    echo ""
}

buildSlimVariant() {
    echo "#####################################"
    echo "精简Variant镜像中……"
    wget https://gist.github.com/ponces/891139a70ee4fdaf1b1c3aed3a59534e/raw/slim.patch -O /tmp/slim.patch
    (cd vendor/gapps && git am /tmp/slim.patch)
    make -j$(nproc --all) systemimage
    (cd vendor/gapps && git reset --hard HEAD~1)
    mv $OUT/system.img $BD/system-treble_arm64_bvS-slim.img
    echo "#####################################"
    echo ""
}

buildVndkliteVariant() {
    echo "#####################################"
    echo "生成VNDKLite镜像中……"
    cd sas-creator
    sudo bash lite-adapter.sh 64 $BD/system-$1.img
    cp s.img $BD/system-$1-vndklite.img
    sudo rm -rf s.img d tmp
    cd ..
    echo "#####################################"
    echo ""
}

generatePackages() {
    if (whiptail --title "提示" --yesno "是否清除旧刷机包？" 10 60) then
        (rm -rf $BD/$prefix*.img.xz) || echo “没有旧刷机包～“
    fi
    echo "#####################################"
    echo "打包所有生成镜像中……"
    BASE_IMAGE=$BD/system-treble_arm64_bvS.img
    xz -cv $BASE_IMAGE -T0 > $BD/PixelExperience_arm64-ab-12.0-$BUILD_DATE-UNOFFICIAL.img.xz
    xz -cv ${BASE_IMAGE%.img}-vndklite.img -T0 > $BD/PixelExperience_arm64-ab-vndklite-12.0-$BUILD_DATE-UNOFFICIAL.img.xz
    xz -cv ${BASE_IMAGE%.img}-slim.img -T0 > $BD/PixelExperience_arm64-ab-slim-12.0-$BUILD_DATE-UNOFFICIAL.img.xz
    xz -cv ${BASE_IMAGE%.img}-slim-vndklite.img -T0 > $BD/PixelExperience_arm64-ab-slim-vndklite-12.0-$BUILD_DATE-UNOFFICIAL.img.xz
    if (whiptail --title "提示" --yesno "是否删除生成好的镜像？" 10 60) then
        rm -rf $BD/system-*.img
    fi
    echo "#####################################"
    echo ""
}

generateOtaJson() {
    echo "#####################################"
    echo "输出OTA更新文件中……"
    prefix="PixelExperience_"
    suffix="-12.0-$BUILD_DATE-UNOFFICIAL.img.xz"
    json="{\"version\": \"$VERSION\",\"date\": \"$(date +%s -d '-8hours')\",\"variants\": ["
    find $BD -name "*.img.xz" | {
        while read file; do
            packageVariant=$(echo $(basename $file) | sed -e s/^$prefix// -e s/$suffix$//)
            case $packageVariant in
                "arm64-ab") name="treble_arm64_bvS";;
                "arm64-ab-vndklite") name="treble_arm64_bvS-vndklite";;
                "arm64-ab-slim") name="treble_arm64_bvS-slim";;
                "arm64-ab-slim-vndklite") name="treble_arm64_bvS-slim-vndklite";;
            esac
            size=$(wc -c $file | awk '{print $1}')
            url="https://github.com/DogDayAndroid/Treble_DogDayAndroid/releases/download/$VERSION/$(basename $file)"
            json="${json} {\"name\": \"$name\",\"size\": \"$size\",\"url\": \"$url\"},"
        done
        json="${json%?}]}"
        echo "$json" | jq . > $BL/ota.json
    }
    echo "#####################################"
    echo ""
}

if (whiptail --title "Treble App" --yesno "是否生成Treble App?" 10 60) then
    buildTrebleApp
fi
buildRegularVariant treble_arm64_bvS
buildSlimVariant  treble_arm64_bvS
buildVndkliteVariant treble_arm64_bvS
buildVndkliteVariant treble_arm64_bvS-slim
generatePackages
generateOtaJson

END=`date +%s`
ELAPSEDM=$(($(($END-$START))/60))
ELAPSEDS=$(($(($END-$START))-$ELAPSEDM*60))
echo "Buildbot completed in $ELAPSEDM minutes and $ELAPSEDS seconds"
echo ""
