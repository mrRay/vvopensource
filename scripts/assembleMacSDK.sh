
#	make the folders for the libs
mkdir -p "build/${BUILD_STYLE}/SDKs/${PRODUCT_NAME}/macosx.sdk/usr/local/lib"

#	copy the libraries to the lib folders
mv -f "build/${BUILD_STYLE}/lib${PRODUCT_NAME}.a" "build/${BUILD_STYLE}/SDKs/${PRODUCT_NAME}/macosx.sdk/usr/local/lib/lib${PRODUCT_NAME}.a"

#	copy the header files
mkdir -p "build/${BUILD_STYLE}/SDKs/${PRODUCT_NAME}/macosx.sdk/usr/local/include"
cp -RfH "build/${BUILD_STYLE}/${PRODUCT_NAME}.framework/Headers" "build/${BUILD_STYLE}/SDKs/${PRODUCT_NAME}/macosx.sdk/usr/local/include/${PRODUCT_NAME}"

#	copy the sdk settings files
cp -RfH "${PRODUCT_NAME}/macosxSDKSettings.plist" "build/${BUILD_STYLE}/SDKs/${PRODUCT_NAME}/macosx.sdk/SDKSettings.plist"

exit 0
