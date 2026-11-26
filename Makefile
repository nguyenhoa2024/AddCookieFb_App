export THEOS_PACKAGE_SCHEME = rootless
TARGET := iphone:clang:latest:14.0
ARCHS = arm64 arm64e
INSTALL_TARGET_PROCESSES = Facebook

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = FBTokenLogin
FBTokenLogin_FILES = Tweak.xm
FBTokenLogin_FRAMEWORKS = Foundation Security
FBTokenLogin_CFLAGS = -fobjc-arc -Os -fvisibility=hidden
FBTokenLogin_LDFLAGS = -Wl,-x

include $(THEOS)/makefiles/tweak.mk
