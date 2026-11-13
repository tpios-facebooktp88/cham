ARCHS = arm64 arm64e
TARGET := iphone:clang:latest:14.0

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = Cham
Cham_FILES = Cham/Entry.xm Cham/CHMOverlay.m Cham/CHMTapScheduler.m Cham/CHMTouchBackend.m Cham/CHMOCRMatcher.m
Cham_FRAMEWORKS = UIKit Foundation Vision
Cham_CFLAGS = -fobjc-arc -Wall -Wextra

include $(THEOS_MAKE_PATH)/tweak.mk
