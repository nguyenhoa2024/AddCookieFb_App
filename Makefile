# Build bang Theos cua roothide (moi truong da build VietSpoof)
export THEOS_PACKAGE_SCHEME = roothide
TARGET := iphone:clang:latest:14.0
ARCHS = arm64 arm64e
INSTALL_TARGET_PROCESSES = Facebook

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = FBTokenLogin
FBTokenLogin_FILES = Tweak.xm
FBTokenLogin_FRAMEWORKS = Foundation Security
FBTokenLogin_CFLAGS = -fobjc-arc

include $(THEOS)/makefiles/tweak.mk
