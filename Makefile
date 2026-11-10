ARCHS = arm64 arm64e
TARGET = iphone:clang:latest:16.0
INSTALL_TARGET_PROCESSES = SpringBoard Preferences
include $(THEOS)/makefiles/common.mk

TWEAK_NAME = C18ConnectivityFive
C18ConnectivityFive_FILES = Tweak.m C18FiveConfig.m C18FiveModules.m C18FivePrefs.m
C18ConnectivityFive_CFLAGS = -fobjc-arc -I.
C18ConnectivityFive_FRAMEWORKS = UIKit Foundation QuartzCore CoreFoundation
C18ConnectivityFive_PRIVATE_FRAMEWORKS = ControlCenterUI ControlCenterUIKit SpringBoardFoundation
C18ConnectivityFive_LIBRARIES = substrate
include $(THEOS_MAKE_PATH)/tweak.mk

after-install::
	install.exec "killall -9 SpringBoard"
