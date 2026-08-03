cmake_minimum_required(VERSION 3.22.1)
project(novella_rs_bridge)

add_library(novella_rs SHARED IMPORTED)
set_target_properties(novella_rs PROPERTIES
  IMPORTED_LOCATION "${CMAKE_CURRENT_LIST_DIR}/../jniLibs/${ANDROID_ABI}/libnovella_rs.so"
  IMPORTED_NO_SONAME TRUE
)

add_library(novella_rs_bridge SHARED NovellaRsJni.cpp)
target_include_directories(novella_rs_bridge PRIVATE
  "${CMAKE_CURRENT_LIST_DIR}/../../../../rust/include"
)
target_link_options(novella_rs_bridge PRIVATE
  "-Wl,-z,max-page-size=16384"
  "-Wl,-z,common-page-size=16384"
)
target_link_libraries(novella_rs_bridge novella_rs log)
