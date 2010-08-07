
#	make the folders for the libs
mkdir -p "build/${BUILD_STYLE}/SDKs/${PRODUCT_NAME}/iphonesimulator.sdk/usr/local/lib"

#	copy the libraries to the lib folders
mv -f "build/${BUILD_STYLE}-iphonesimulator/lib${PRODUCT_NAME}.a" "build/${BUILD_STYLE}/SDKs/${PRODUCT_NAME}/iphonesimulator.sdk/usr/local/lib/lib${PRODUCT_NAME}.a"

#	copy the header files
mkdir -p "build/${BUILD_STYLE}/SDKs/${PRODUCT_NAME}/iphonesimulator.sdk/usr/local/include"
cp -RfH "build/${BUILD_STYLE}/${PRODUCT_NAME}.framework/Headers" "build/${BUILD_STYLE}/SDKs/${PRODUCT_NAME}/iphonesimulator.sdk/usr/local/include/${PRODUCT_NAME}"

#	copy the license
cp -RfH "lgpl-3.0.txt" "build/${BUILD_STYLE}/SDKs/${PRODUCT_NAME}/iphonesimulator.sdk/usr/local/include/${PRODUCT_NAME}"

#	modify the header files for the iphone SDKs
echo "#define IPHONE 1" > "build/tmpFile.txt"
cat "${PRODUCT_NAME}/${PRODUCT_NAME}.h" >> "build/tmpFile.txt"
mv "build/tmpFile.txt" "build/${BUILD_STYLE}/SDKs/${PRODUCT_NAME}/iphonesimulator.sdk/usr/local/include/${PRODUCT_NAME}/${PRODUCT_NAME}.h"

#	copy the sdk settings plist, modifying it so the iphone os deployment target used to build the SDK is inserted
sed "s/XXXXXX/${IPHONEOS_DEPLOYMENT_TARGET}/" "${PRODUCT_NAME}/iphonesimulatorSDKSettings.plist" > "build/${BUILD_STYLE}/SDKs/${PRODUCT_NAME}/iphonesimulator.sdk/SDKSettings.plist"

#	delete the build product folders for iphone stuff (tidying stuff up)
rm -rf "build/${BUILD_STYLE}-iphonesimulator"

exit 0
