#!/usr/bin/env bash

#
# Script For Building Android Kernel
#

MODEL="Redmi Note 7"

DEFCONFIG=lavender-perf_defconfig

KERNEL_DIR=${PWD}

IMAGE=${PWD}/out/arch/arm64/boot/Image.gz-dtb

# create config file for build variant info
echo $@ > my.conf
conf=${KERNEL_DIR}/my.conf

# Specify compiler.
# 'aosp', 'azure' or 'gcc'
if grep "aosp" $conf; then
COMPILER=aosp
  if grep "full-lto" $conf; then
		if grep "oldcam" $conf; then
			CCACHE_BRANCH=aosp-13-oldcam
		elif grep "newcam" $conf; then
			CCACHE_BRANCH=aosp-13-newcam
		elif grep "qti" $conf; then
			CCACHE_BRANCH=aosp-13-qti
		fi
  else
	if grep "oldcam" $conf; then
		CCACHE_BRANCH=aosp-13-thin-oldcam
	elif grep "newcam" $conf; then
		CCACHE_BRANCH=aosp-13-thin-newcam
	elif grep "qti" $conf; then
		CCACHE_BRANCH=aosp-13-thin-qti
	fi
  fi
elif grep "azure" $conf; then
COMPILER=azure
	if grep "oldcam" $conf; then
		CCACHE_BRANCH=azure-oldcam
	elif grep "newcam" $conf; then
		CCACHE_BRANCH=aazure-newcam
	elif grep "qti" $conf; then
		CCACHE_BRANCH=azure-qti
	fi
  else
	if grep "oldcam" $conf; then
		CCACHE_BRANCH=azure-thin-oldcam
	elif grep "newcam" $conf; then
		CCACHE_BRANCH=azure-thin-newcam
	elif grep "qti" $conf; then
		CCACHE_BRANCH=azure-thin-qti
	fi
  fi
elif grep "gcc" $conf; then
COMPILER=gcc
CCACHE_BRANCH=gcc-
if grep "oldcam" $conf; then
	CCACHE_BRANCH=gcc-oldcam
elif grep "newcam" $conf; then
	CCACHE_BRANCH=gcc-newcam
elif grep "qti" $conf; then
	CCACHE_BRANCH=gcc-qti
fi
fi

# enable FULL_LTO (default THIN_LTO)
if grep "full-lto" $conf; then
	sed -i 's/CONFIG_THINLTO=y/# CONFIG_THINLTO is not set/' arch/arm64/configs/lavender-perf_defconfig
fi

# disable LTO
if grep "no-lto" $conf; then
	sed -i 's/CONFIG_LTO=y/# CONFIG_LTO is not set/' arch/arm64/configs/lavender-perf_defconfig
	sed -i 's/CONFIG_LTO_CLANG=y/# CONFIG_LTO_CLANG is not set/' arch/arm64/configs/lavender-perf_defconfig
	sed -i 's/# CONFIG_LTO_NONE is not set=y/CONFIG_LTO_NONE=y/' arch/arm64/configs/lavender-perf_defconfig
fi

# Specify built variant
# 'oldcam', 'newcam' or 'qti'
if grep "qti" $conf; then
TYPE=QTI
elif grep "oldcam" $conf; then
TYPE=Oldcam
elif grep "newcam" $conf; then
TYPE=Newcam
fi

# Verbose build
VERBOSE=0

export PROCS=$(nproc --all)

# Set Date
DATE=$(TZ=Asia/Kolkata date +"%Y%m%d-%T")
START=$(date +"%s")
TANGGAL=$(date +"%F-%S")

# Commit Head
COMMIT_HEAD=$(git log --oneline -1)

# Kernel Version
KERVER=$(make kernelversion)

function download_ccache() {
  if grep "ccache" $conf; then
  echo "|| Downloading CCACHE ||"
	git config --global user.name ZenitsuID
	git config --global user.email zenitsuxd5@gmail.com
  xd_info "Downloading CCACHE..."
	git clone --depth=1 https://ZenitsuID:$gh_token@github.com/ZenitsuID/drone_ccache_backups.git -b ${CCACHE_BRANCH} ${CCACHE_BRANCH}
	xd_info "Exported CCACHE $(du ${KERNEL_DIR}/${CCACHE_BRANCH} -sh)"
  export CCACHE_DIR=${KERNEL_DIR}/${CCACHE_BRANCH}
  export CCACHE_EXEC=$(which ccache)
  export USE_CCACHE=1
  ccache -M 8G
  ccache -z
  fi
}

function upload_ccache() {
  if grep "ccache" $conf; then
  echo "|| Uploading CCACHE ||"
	cd ${KERNEL_DIR}/${CCACHE_BRANCH}
	# 7za a -tzip -v45m ${TYPE}.zip ccache_repo/* -sdel
	xd_info "Collecting CCACHE Backup..."
	git add -f -A
	git commit -sm "CCACHE: IMPORT CCACHE FROM NEW BUILD"
  xd_info "Uploading CCACHE Backup..."
	git push -f
	xd_info "Uploaded!"
	fi
}


# Send info plox channel
function xd_info() {
	# dont send thi msg for all 3 build variant, (oldcam/newcam/qti)
	if grep "oldcam" $conf; then
    curl -s -X POST "https://api.telegram.org/bot$token/sendMessage" \
        -d chat_id="$chat_id" \
        -d "disable_web_page_preview=true" \
        -d "parse_mode=html" \
        -d text="$1"
	fi
}

clone() {
	echo " Cloning Dependencies "
	if [[ $COMPILER = "gcc" ]]
	then
		echo "|| Cloning GCC ||"
		git clone --depth=1 https://github.com/mvaisakh/gcc-arm64.git/ -b gcc-new gcc64
		git clone --depth=1 https://github.com/mvaisakh/gcc-arm.git/ -b gcc-new gcc32
    export PATH=${KERNEL_DIR}/gcc64/bin/:${KERNEL_DIR}/gcc32/bin/:/usr/bin:$PATH
    export KBUILD_COMPILER_STRING=$(${KERNEL_DIR}/gcc64/bin/aarch64-elf-gcc --version | head -n 1)
	elif [[ $COMPILER = "azure" ]]
	then
		echo  "|| Cloning Azure Clang-14 ||"
		git clone --depth=1 https://gitlab.com/Panchajanya1999/azure-clang.git/ clang
    export PATH=${KERNEL_DIR}/clang/bin:$PATH
    export KBUILD_COMPILER_STRING=$(${KERNEL_DIR}/clang/bin/clang --version | head -n 1 | perl -pe 's/\(http.*?\)//gs' | sed -e 's/  */ /g')
  elif [[ $COMPILER = "aosp" ]]
	then
    echo "|| Cloning AOSP-13 ||"
    git clone https://gitlab.com/crdroidandroid/android_prebuilts_clang_host_linux-x86_clang-r433403 -b 11.0 --depth=1 clang
    git clone https://github.com/sohamxda7/llvm-stable.git/ -b gcc64 --depth=1 gcc
    git clone https://github.com/sohamxda7/llvm-stable.git/ -b gcc32 --depth=1 gcc32
    export PATH=${KERNEL_DIR}/clang/bin:${KERNEL_DIR}/gcc/bin:${KERNEL_DIR}/gcc32/bin:${PATH}
    export KBUILD_COMPILER_STRING=$(${KERNEL_DIR}/clang/bin/clang --version | head -n 1 | perl -pe 's/\(http.*?\)//gs' | sed -e 's/  */ /g')
  fi
	echo "|| Cloning Anykernel ||"
	git clone --depth=1 https://github.com/who-em-i/AnyKernel3.git AnyKernel3
}

# Export
function exports() {
export ARCH=arm64
export SUBARCH=arm64
export KBUILD_BUILD_HOST=DroneCI
export KBUILD_BUILD_USER="ZenitsuID"
}

# Send info plox channel
function sendinfo() {
    curl -s -X POST "https://api.telegram.org/bot$token/sendMessage" \
        -d chat_id="$chat_id" \
        -d "disable_web_page_preview=true" \
        -d "parse_mode=html" \
        -d text="<b>•  bEast Kernel  •</b>%0ABuild started on <code>Drone CI</code>%0AFor device <b>Xiaomi Redmi Note7/7S</b> (lavender)%0ABranch: <code>$(git rev-parse --abbrev-ref HEAD)</code>%0A<b>Kernel Version : </b><code>$KERVER</code>%0ACompiler Used: <code>${KBUILD_COMPILER_STRING}</code>%0AType: <code>#${TYPE}</code>%0A<b>COMMIT_HEAD : </b><a href='$DRONE_COMMIT_LINK'>$COMMIT_HEAD</a>%0A<b>Build Status:</b>#HMP-Beta"
}
# Push kernel to channel
function push() {
    cd AnyKernel3
    ZIP=$(echo *.zip)
    curl -F document=@$ZIP "https://api.telegram.org/bot$token/sendDocument" \
        -F chat_id="$chat_id" \
        -F "disable_web_page_preview=true" \
        -F "parse_mode=html" \
        -F caption="Build took $(($DIFF / 60)) minute(s) and $(($DIFF % 60)) second(s). | For <b>Redmi Note 7/7s (lavender)</b> | <b>${KBUILD_COMPILER_STRING}</b>"
}
# Fin Error
function finerr() {
    LOG=error.log
   curl -F document=@$LOG "https://api.telegram.org/bot$token/sendDocument" \
        -F chat_id="$chat_id" \
        -F "disable_web_page_preview=true" \
        -F "parse_mode=html" \
        -F caption="Build throw an error(s)"
    exit 1
}
# Compile plox
function compile() {
	if [[ $COMPILER = "azure" ]]
	then
		make O=out ARCH=arm64 ${DEFCONFIG}
		make -j$(nproc --all) O=out \
				ARCH=arm64 \
				CC="ccache clang" \
				LD=ld.lld \
				AR=llvm-ar \
				NM=llvm-nm \
				OBJCOPY=llvm-objcopy \
				OBJDUMP=llvm-objdump \
				STRIP=llvm-strip \
				V=$VERBOSE \
				CROSS_COMPILE_ARM32=arm-linux-gnueabi- \
				CROSS_COMPILE=aarch64-linux-gnu- 2>&1 | tee error.log
	elif [[ $COMPILER = "gcc" ]]
	then
	        make O=out ARCH=arm64 ${DEFCONFIG}
	        make -j$(nproc --all) O=out \
			        ARCH=arm64 \
			        CROSS_COMPILE=aarch64-elf- \
      				CC="ccache gcc" \
			        LD=aarch64-elf-ld.lld \
			        AR=aarch64-elf-ar \
			        OBJDUMP=aarch64-elf-objdump \
			        STRIP=aarch64-elf-strip \
			        V=$VERBOSE \
			        CROSS_COMPILE_ARM32=arm-eabi- | tee error.log
	elif [[ $COMPILER = "aosp" ]]
	then
	        make O=out ARCH=arm64 ${DEFCONFIG}
	        make -j$(nproc --all) O=out \
      				ARCH=arm64 \
      				CLANG_TRIPLE=aarch64-linux-gnu- \
      				CROSS_COMPILE=aarch64-linux-android- \
      				CROSS_COMPILE_ARM32=arm-linux-androideabi- \
      				CC="ccache clang" \
      				LD=ld.lld \
      				AR=llvm-ar \
      				NM=llvm-nm \
      				OBJCOPY=llvm-objcopy \
      				OBJDUMP=llvm-objdump \
      				READELF=llvm-readelf \
      				OBJSIZE=llvm-size \
      				STRIP=llvm-strip \
      				HOSTCC=clang \
              V=$VERBOSE \
      				HOSTCXX=clang++ | tee error.log
	fi

    if ! [ -a "$IMAGE" ]; then
        finerr
        exit 1
    fi
    cp $IMAGE AnyKernel3
}
# Zipping
function zipping() {
    cd AnyKernel3 || exit 1
    zip -r9 bEast-HMP-${TYPE}-Kernel-${TANGGAL}.zip * -x README.md .git
    cd ..
}
clone
sendinfo
download_ccache
exports
compile
zipping
END=$(date +"%s")
DIFF=$(($END - $START))
push
upload_ccache
