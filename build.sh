#!/bin/bash
if (whiptail --title "DogDayAndroid源码自动构建机器人" --yesno "5秒后开始进行构建\n参考:github.com/ponces/treble_build_pe\n编写:easternDay" 10 60) then
    echo ""
    sleep 5
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
# 版本号
VERSION="v401"

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
if (whiptail --title "是否同步" --yesno "此选项决定你是否进行本地代码同步拉取。\n如果你是第一次运行请选择<YES>。" 10 60) then
    echo "#####################################"
    echo "同步仓库中……"
    repo sync -c --force-sync --no-clone-bundle --no-tags -j$(nproc --all)
    echo "#####################################"
    echo ""
fi

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

echo "[4] 应用专用设备补丁"
bash $BL/apply-patches.sh $BL a40
echo "#####################################"
echo ""

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

buildVariant() {
    echo "#####################################"
    echo "构建Variant镜像中……"
    lunch ${1}-userdebug
    make installclean
    make -j$(nproc --all) systemimage
    make vndk-test-sepolicy
    mv $OUT/system.img $BD/system-$1.img
    buildSlimVariant $1
    rm -rf out/target/product/phhgsi*
    echo "#####################################"
    echo ""
}

buildSlimVariant() {
    echo "#####################################"
    echo "精简Variant镜像中……"
    wget https://gist.github.com/ponces/891139a70ee4fdaf1b1c3aed3a59534e/raw/slim.patch -O /tmp/slim.patch
    (cd vendor/gapps && git am /tmp/slim.patch)
    lunch ${1}-userdebug
    make -j$(nproc --all) systemimage
    mv $OUT/system.img $BD/system-$1-slim.img
    (cd vendor/gapps && git reset --hard HEAD~1)
    echo "#####################################"
    echo ""
}

buildSasImages() {
    echo "#####################################"
    echo "生成VNDKLite镜像中……"
    cd sas-creator
    sudo bash lite-adapter.sh 64 $BD/system-treble_arm64_bvS.img
    cp s.img $BD/system-treble_arm64_bvS-vndklite.img
    sudo rm -rf s.img d tmp
    cd ..
    echo "#####################################"
    echo ""
}

generatePackages() {
    echo "#####################################"
    echo "打包所有生成镜像中……"
    BASE_IMAGE=$BD/system-treble_arm64_bvS.img
    xz -cv $BASE_IMAGE -T0 > $BD/PixelExperience_arm64-ab-12.0-$BUILD_DATE-UNOFFICIAL.img.xz
    xz -cv ${BASE_IMAGE%.img}-vndklite.img -T0 > $BD/PixelExperience_arm64-ab-vndklite-12.0-$BUILD_DATE-UNOFFICIAL.img.xz
    xz -cv ${BASE_IMAGE%.img}-slim.img -T0 > $BD/PixelExperience_arm64-ab-slim-12.0-$BUILD_DATE-UNOFFICIAL.img.xz
    rm -rf $BD/system-*.img
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
            esac
            size=$(wc -c $file | awk '{print $1}')
            url="https://github.com/ponces/treble_build_pe/releases/download/$VERSION/$(basename $file)"
            json="${json} {\"name\": \"$name\",\"size\": \"$size\",\"url\": \"$url\"},"
        done
        json="${json%?}]}"
        echo "$json" | jq . > $BL/ota.json
    }
    echo "#####################################"
    echo ""
}

buildTrebleApp
buildVariant treble_arm64_bvS
buildSasImages
generatePackages
generateOtaJson

END=`date +%s`
ELAPSEDM=$(($(($END-$START))/60))
ELAPSEDS=$(($(($END-$START))-$ELAPSEDM*60))
echo "Buildbot completed in $ELAPSEDM minutes and $ELAPSEDS seconds"
echo ""
