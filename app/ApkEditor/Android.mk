LOCAL_PATH := $(call my-dir)
include $(CLEAR_VARS)
# Module name should match apk name to be installed
LOCAL_MODULE := ApkEditor
LOCAL_MODULE_TAGS := optional
# 指定 src 目录
LOCAL_SRC_FILES := $(LOCAL_MODULE).apk
LOCAL_MODULE_CLASS := APPS
LOCAL_MODULE_SUFFIX := $(COMMON_ANDROID_PACKAGE_SUFFIX)
LOCAL_MODULE_PATH := $(TARGET_OUT_SYSTEM_APPS)
# 签名
LOCAL_CERTIFICATE := PRESIGNED
LOCAL_ENFORCE_USES_LIBRARIES := false

include $(BUILD_PREBUILT)