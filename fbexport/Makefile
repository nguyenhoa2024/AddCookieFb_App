export THEOS_PACKAGE_SCHEME = rootless
TARGET := iphone:clang:latest:14.0
ARCHS = arm64 arm64e
INSTALL_TARGET_PROCESSES = Facebook

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = FBTokenExport
FBTokenExport_FILES = Tweak.xm
FBTokenExport_FRAMEWORKS = Foundation Security UIKit
FBTokenExport_CFLAGS = -fobjc-arc -Os -fvisibility=hidden
FBTokenExport_LDFLAGS = -Wl,-x

include $(THEOS)/makefiles/tweak.mk
