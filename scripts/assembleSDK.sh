#	an SDK is really just a folder, with sub-folders for the different static libs for each platform
#	the SDKs in this case look something like this
#
#		VVBasics
#			iphoneos.sdk
#				SDKSettings.plist
#				usr
#					local
#						include
#							VVBasics
#								Headers
#									<all the headers>
#								<all the headers>
#						lib
#							libVVBasics.a
#			iphonesimulator.sdk
#				<same as above iphoneos.sdk>
#			macosx.sdk
#				<same as above, iphoneos.sdk>
#		VVMIDI
#			<same as above, VVBasics>
#		VVOSC
#			<same as above, VVBasics>
#

#	make the temp folder for assembling the SDK
mkdir -p "${BUILD_DIR}/${PRODUCT_NAME}/${PLATFORM_NAME}.sdk/usr/local/lib/"
#	...the folder i'll want to move at the end is ${BUILD_DIR}/${PRODUCT_NAME}/${PLATFORM_NAME}.sdk, which will go in ~/Library/SDKs/${PRODUCT_NAME}/


#	move the library i compiled to the lib folder
mv -f "${TARGET_BUILD_DIR}/lib${PRODUCT_NAME}.a" "${BUILD_DIR}/${PRODUCT_NAME}/${PLATFORM_NAME}.sdk/usr/local/lib/lib${PRODUCT_NAME}.a"

#	these are just some environment variables (you can show these in the settings for the run script build phase)
#			${BUILD_DIR}/${CONFIGURATION}${EFFECTIVE_PLATFORM_NAME}
#			"full path ending in /Build/Products" ${BUILD_DIR}
#			"full path ending in /Build/Products/Release-iphonesimulator"	${BUILT_PRODUCTS_DIR}
#			"Release"	${CONFIGURATION}
#			"-iphonesimulator"	${EFFECTIVE_PLATFORM_NAME}
#			"iphonesimulator"	${PLATFORM_NAME}


#	make the 'include' folder, copy the folder of header files into it
mkdir -p "${BUILD_DIR}/${PRODUCT_NAME}/${PLATFORM_NAME}.sdk/usr/local/include"
cp -RfH "${BUILD_DIR}/Release/${PRODUCT_NAME}.framework/Headers" "${BUILD_DIR}/${PRODUCT_NAME}/${PLATFORM_NAME}.sdk/usr/local/include/${PRODUCT_NAME}"

#	copy the license
cp -RfH "lgpl-3.0.txt" "${BUILD_DIR}/${PRODUCT_NAME}/${PLATFORM_NAME}.sdk/usr/local/include/${PRODUCT_NAME}"

#	modify the header files for the iphone SDKs
if [ "${PLATFORM_NAME}" != "macosx" ]
then
	echo "#define IPHONE 1" > "${BUILD_DIR}/tmpFile-${PLATFORM_NAME}.txt"
fi
cat "${PRODUCT_NAME}/${PRODUCT_NAME}.h" >> "${BUILD_DIR}/tmpFile-${PLATFORM_NAME}.txt"
mv "${BUILD_DIR}/tmpFile-${PLATFORM_NAME}.txt" "${BUILD_DIR}/${PRODUCT_NAME}/${PLATFORM_NAME}.sdk/usr/local/include/${PRODUCT_NAME}/${PRODUCT_NAME}.h"



#	copy the sdk settings plist, modifying it so the iphone os deployment target used to build the SDK is inserted
sed "s/XXXXXX/${IPHONEOS_DEPLOYMENT_TARGET}/" "scripts/${PLATFORM_NAME}SDKSettings.plist" > "${BUILD_DIR}/${PRODUCT_NAME}/${PLATFORM_NAME}.sdk/SDKSettings.plist"


if (test ! -e "${HOME}/Library/SDKs/${PRODUCT_NAME}")
then
	mkdir -p "${HOME}/Library/SDKs/${PRODUCT_NAME}"
fi


#	remove the existing SDK (if there is one)
rm -rf "${HOME}/Library/SDKs/${PRODUCT_NAME}/${PLATFORM_NAME}.sdk"
#	install the newly-compiled SDK
cp -RfH "${BUILD_DIR}/${PRODUCT_NAME}/${PLATFORM_NAME}.sdk" "${HOME}/Library/SDKs/${PRODUCT_NAME}/${PLATFORM_NAME}.sdk"





#	delete the build product folders for iphone stuff (tidying stuff up)
rm -rf "${BUILD_DIR}/${PRODUCT_NAME}"

exit 0
