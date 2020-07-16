#!/bin/bash

BUILD_DIR=../bin
RFS_DIR=$BUILD_DIR/rootfs
ARCHIV_NAME=rootfs.tar.gz

ROOT_TARGET=$RFS_DIR/home/root
GEN_SD_CONT_DIR=../mpsoc/os/build/Vitis-AI/DPU-TRD-ULTRA96V2/prj/Vitis/binary_container_1/sd_card/
XILINX_VAI_DIR=$BUILD_DIR/xilinx_vai_board_package

BAUMER_GAPI=../mpsoc/os/build/baumer-gapi-sdk-linux-v2.10.0.25119-gcc-5.4-aarch64.tar.gz
BAUMER_EXTR=$BUILD_DIR/baumer

TESTSET=../mpsoc/os/build/Vitis-AI/DPU-TRD-ULTRA96V2/app/Vitis/samples/resnet50/img
WORDS=../mpsoc/os/build/Vitis-AI/mpsoc/dnndk_samples_zcu104/dataset/image500_640_480/words.txt

BOOT_BIN=$GEN_SD_CONT_DIR/BOOT.BIN
IMAGE_UB=$GEN_SD_CONT_DIR/image.ub

RFS=$GEN_SD_CONT_DIR/rootfs.tar.gz
DPU_XCLBIN=$GEN_SD_CONT_DIR/dpu.xclbin
APPLICATION=../sw/inference/build/ai_application

OPENCV_SRC=../mpsoc/os/build/opencv/build/install

sudo rm -rf $BUILD_DIR
mkdir -p $BUILD_DIR
mkdir -p $RFS_DIR
mkdir -p $BAUMER_EXTR

####################### Docker Session to copy VAI Board Package #######################

IMAGE_NAME=xilinx/vitis-ai:runtime-1.0.0-cpu
CONTAINERNAME=docker-vitis-ai-runtime-compile
DOCKER_SH_SCRIPT=util/dockerscripts/get_package.sh
CWD=$(pwd)
ROOT=$CWD/..

user=`whoami`
uid=`id -u`
gid=`id -g`

xclmgmt_driver="$(find /dev -name xclmgmt\*)"
docker_devices=""
for i in ${xclmgmt_driver} ;
do
  docker_devices+="--device=$i "
done

render_driver="$(find /dev/dri -name renderD\*)"
for i in ${render_driver} ;
do
  docker_devices+="--device=$i "
done

docker run \
    -d \
    $docker_devices \
    -v /opt/xilinx/dsa:/opt/xilinx/dsa \
    -v /opt/xilinx/overlaybins:/opt/xilinx/overlaybins \
    -e USER=$user -e UID=$uid -e GID=$gid \
    -v $ROOT:/workspace \
    -w /workspace \
    -it \
    --rm \
    --name $CONTAINERNAME \
    --network=host \
    $IMAGE_NAME \
    bash

docker exec $CONTAINERNAME ./$DOCKER_SH_SCRIPT

docker stop $CONTAINERNAME

#####################################################################################

# Copy Boot files to the Build directory
cp $BOOT_BIN $BUILD_DIR
cp $IMAGE_UB $BUILD_DIR

# Extract Baumer GAPI
tar xf $BAUMER_GAPI -C $BAUMER_EXTR

# Extract Root File System
sudo tar -xf $RFS -C $RFS_DIR

# Make directory to copy the testset
sudo mkdir -p $ROOT_TARGET/dataset/image500_640_480/

# Make directories to install dnndk tools 
sudo mkdir -p $RFS_DIR/usr/local/bin
sudo mkdir -p $RFS_DIR/usr/local/lib
sudo mkdir -p $RFS_DIR/etc/ld.so.conf.d

# Make directories to install Baumer GAPI
sudo mkdir -p $RFS_DIR/usr/local/lib/baumer
sudo mkdir -p $RFS_DIR/usr/local/src/baumer/inc

# Copy the AI Application
sudo cp $APPLICATION $ROOT_TARGET
sudo cp $TESTSET/* $ROOT_TARGET/dataset/image500_640_480/
sudo cp $WORDS $ROOT_TARGET/dataset/image500_640_480

# Copy DPU-Kernel in the RFS
sudo cp $DPU_XCLBIN $RFS_DIR/usr/lib

# Install dnndk tools
sudo cp $XILINX_VAI_DIR/pkgs/bin/* $RFS_DIR/usr/local/bin/
sudo cp $XILINX_VAI_DIR/pkgs/lib/* $RFS_DIR/usr/local/lib/
sudo cp -r $XILINX_VAI_DIR/pkgs/include/* $RFS_DIR/usr/include
echo "/usr/local/lib" | sudo tee $RFS_DIR/etc/ld.so.conf.d/dnndk.conf

# Install Baumer GAPI
sudo cp -r $BAUMER_EXTR/lib/* $RFS_DIR/usr/local/lib/baumer
sudo cp -r $BAUMER_EXTR/include/* $RFS_DIR/usr/local/src/baumer/inc
# sudo cp ../mpsoc/os/build/baumer-gapi-sdk-linux-v2.10.0.25119-gcc-5.4-aarch64.deb $ROOT_TARGET
echo "usr/local/lib/baumer" | sudo tee $RFS_DIR/etc/ld.so.conf.d/lib_baumer.conf

# Install Baumer Application
sudo cp -r ../sw/inference/src/camera-interface $ROOT_TARGET

# Install OpenCV (not needed, is installed on builded rootfs)
# sudo cp -r $OPENCV_SRC/* $RFS_DIR/usr

# configure dynamic linker run-time bindings
sudo ldconfig -r $RFS_DIR

# Copy the cross compiled Application
sudo cp ../../compile/bild/AIonFPGA $ROOT_TARGET

# Compress Root File System
sudo tar -czf $BUILD_DIR/$ARCHIV_NAME -C $RFS_DIR .

# Remove temporarily created folders
# sudo rm -rf $XILINX_VAI_DIR
# sudo rm -rf $RFS_DIR
# sudo rm -rf $BAUMER_EXTR
