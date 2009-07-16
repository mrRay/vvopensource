
#	remove the existing SDK (if there is one)
rm -rf "${HOME}/Library/SDKs/${PRODUCT_NAME}"
#	install the newly-compiled SDK
cp -RfH "build/${BUILD_STYLE}/SDKs/${PRODUCT_NAME}" "${HOME}/Library/SDKs/${PRODUCT_NAME}"

exit 0
