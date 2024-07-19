include(cmake/SystemLink.cmake)
include(CMakeDependentOption)
include(CheckCXXCompilerFlag)


macro(trans_include_detector_supports_sanitizers)
  if((CMAKE_CXX_COMPILER_ID MATCHES ".*Clang.*" OR CMAKE_CXX_COMPILER_ID MATCHES ".*GNU.*") AND NOT WIN32)
    set(SUPPORTS_UBSAN ON)
  else()
    set(SUPPORTS_UBSAN OFF)
  endif()

  if((CMAKE_CXX_COMPILER_ID MATCHES ".*Clang.*" OR CMAKE_CXX_COMPILER_ID MATCHES ".*GNU.*") AND WIN32)
    set(SUPPORTS_ASAN OFF)
  else()
    set(SUPPORTS_ASAN ON)
  endif()
endmacro()

macro(trans_include_detector_setup_options)
  option(trans_include_detector_ENABLE_HARDENING "Enable hardening" ON)
  option(trans_include_detector_ENABLE_COVERAGE "Enable coverage reporting" OFF)
  cmake_dependent_option(
    trans_include_detector_ENABLE_GLOBAL_HARDENING
    "Attempt to push hardening options to built dependencies"
    ON
    trans_include_detector_ENABLE_HARDENING
    OFF)

  trans_include_detector_supports_sanitizers()

  if(NOT PROJECT_IS_TOP_LEVEL OR trans_include_detector_PACKAGING_MAINTAINER_MODE)
    option(trans_include_detector_ENABLE_IPO "Enable IPO/LTO" OFF)
    option(trans_include_detector_WARNINGS_AS_ERRORS "Treat Warnings As Errors" OFF)
    option(trans_include_detector_ENABLE_USER_LINKER "Enable user-selected linker" OFF)
    option(trans_include_detector_ENABLE_SANITIZER_ADDRESS "Enable address sanitizer" OFF)
    option(trans_include_detector_ENABLE_SANITIZER_LEAK "Enable leak sanitizer" OFF)
    option(trans_include_detector_ENABLE_SANITIZER_UNDEFINED "Enable undefined sanitizer" OFF)
    option(trans_include_detector_ENABLE_SANITIZER_THREAD "Enable thread sanitizer" OFF)
    option(trans_include_detector_ENABLE_SANITIZER_MEMORY "Enable memory sanitizer" OFF)
    option(trans_include_detector_ENABLE_UNITY_BUILD "Enable unity builds" OFF)
    option(trans_include_detector_ENABLE_CLANG_TIDY "Enable clang-tidy" OFF)
    option(trans_include_detector_ENABLE_CPPCHECK "Enable cpp-check analysis" OFF)
    option(trans_include_detector_ENABLE_PCH "Enable precompiled headers" OFF)
    option(trans_include_detector_ENABLE_CACHE "Enable ccache" OFF)
  else()
    option(trans_include_detector_ENABLE_IPO "Enable IPO/LTO" ON)
    option(trans_include_detector_WARNINGS_AS_ERRORS "Treat Warnings As Errors" ON)
    option(trans_include_detector_ENABLE_USER_LINKER "Enable user-selected linker" OFF)
    option(trans_include_detector_ENABLE_SANITIZER_ADDRESS "Enable address sanitizer" ${SUPPORTS_ASAN})
    option(trans_include_detector_ENABLE_SANITIZER_LEAK "Enable leak sanitizer" OFF)
    option(trans_include_detector_ENABLE_SANITIZER_UNDEFINED "Enable undefined sanitizer" ${SUPPORTS_UBSAN})
    option(trans_include_detector_ENABLE_SANITIZER_THREAD "Enable thread sanitizer" OFF)
    option(trans_include_detector_ENABLE_SANITIZER_MEMORY "Enable memory sanitizer" OFF)
    option(trans_include_detector_ENABLE_UNITY_BUILD "Enable unity builds" OFF)
    option(trans_include_detector_ENABLE_CLANG_TIDY "Enable clang-tidy" ON)
    option(trans_include_detector_ENABLE_CPPCHECK "Enable cpp-check analysis" ON)
    option(trans_include_detector_ENABLE_PCH "Enable precompiled headers" OFF)
    option(trans_include_detector_ENABLE_CACHE "Enable ccache" ON)
  endif()

  if(NOT PROJECT_IS_TOP_LEVEL)
    mark_as_advanced(
      trans_include_detector_ENABLE_IPO
      trans_include_detector_WARNINGS_AS_ERRORS
      trans_include_detector_ENABLE_USER_LINKER
      trans_include_detector_ENABLE_SANITIZER_ADDRESS
      trans_include_detector_ENABLE_SANITIZER_LEAK
      trans_include_detector_ENABLE_SANITIZER_UNDEFINED
      trans_include_detector_ENABLE_SANITIZER_THREAD
      trans_include_detector_ENABLE_SANITIZER_MEMORY
      trans_include_detector_ENABLE_UNITY_BUILD
      trans_include_detector_ENABLE_CLANG_TIDY
      trans_include_detector_ENABLE_CPPCHECK
      trans_include_detector_ENABLE_COVERAGE
      trans_include_detector_ENABLE_PCH
      trans_include_detector_ENABLE_CACHE)
  endif()

endmacro()

macro(trans_include_detector_global_options)
  if(trans_include_detector_ENABLE_IPO)
    include(cmake/InterproceduralOptimization.cmake)
    trans_include_detector_enable_ipo()
  endif()

  trans_include_detector_supports_sanitizers()

  if(trans_include_detector_ENABLE_HARDENING AND trans_include_detector_ENABLE_GLOBAL_HARDENING)
    include(cmake/Hardening.cmake)
    if(NOT SUPPORTS_UBSAN 
       OR trans_include_detector_ENABLE_SANITIZER_UNDEFINED
       OR trans_include_detector_ENABLE_SANITIZER_ADDRESS
       OR trans_include_detector_ENABLE_SANITIZER_THREAD
       OR trans_include_detector_ENABLE_SANITIZER_LEAK)
      set(ENABLE_UBSAN_MINIMAL_RUNTIME FALSE)
    else()
      set(ENABLE_UBSAN_MINIMAL_RUNTIME TRUE)
    endif()
    message("${trans_include_detector_ENABLE_HARDENING} ${ENABLE_UBSAN_MINIMAL_RUNTIME} ${trans_include_detector_ENABLE_SANITIZER_UNDEFINED}")
    trans_include_detector_enable_hardening(trans_include_detector_options ON ${ENABLE_UBSAN_MINIMAL_RUNTIME})
  endif()
endmacro()

macro(trans_include_detector_local_options)
  if(PROJECT_IS_TOP_LEVEL)
    include(cmake/StandardProjectSettings.cmake)
  endif()

  add_library(trans_include_detector_warnings INTERFACE)
  add_library(trans_include_detector_options INTERFACE)

  include(cmake/CompilerWarnings.cmake)
  trans_include_detector_set_project_warnings(
    trans_include_detector_warnings
    ${trans_include_detector_WARNINGS_AS_ERRORS}
    ""
    ""
    ""
    "")

  if(trans_include_detector_ENABLE_USER_LINKER)
    include(cmake/Linker.cmake)
    trans_include_detector_configure_linker(trans_include_detector_options)
  endif()

  include(cmake/Sanitizers.cmake)
  trans_include_detector_enable_sanitizers(
    trans_include_detector_options
    ${trans_include_detector_ENABLE_SANITIZER_ADDRESS}
    ${trans_include_detector_ENABLE_SANITIZER_LEAK}
    ${trans_include_detector_ENABLE_SANITIZER_UNDEFINED}
    ${trans_include_detector_ENABLE_SANITIZER_THREAD}
    ${trans_include_detector_ENABLE_SANITIZER_MEMORY})

  set_target_properties(trans_include_detector_options PROPERTIES UNITY_BUILD ${trans_include_detector_ENABLE_UNITY_BUILD})

  if(trans_include_detector_ENABLE_PCH)
    target_precompile_headers(
      trans_include_detector_options
      INTERFACE
      <vector>
      <string>
      <utility>)
  endif()

  if(trans_include_detector_ENABLE_CACHE)
    include(cmake/Cache.cmake)
    trans_include_detector_enable_cache()
  endif()

  include(cmake/StaticAnalyzers.cmake)
  if(trans_include_detector_ENABLE_CLANG_TIDY)
    trans_include_detector_enable_clang_tidy(trans_include_detector_options ${trans_include_detector_WARNINGS_AS_ERRORS})
  endif()

  if(trans_include_detector_ENABLE_CPPCHECK)
    trans_include_detector_enable_cppcheck(${trans_include_detector_WARNINGS_AS_ERRORS} "" # override cppcheck options
    )
  endif()

  if(trans_include_detector_ENABLE_COVERAGE)
    include(cmake/Tests.cmake)
    trans_include_detector_enable_coverage(trans_include_detector_options)
  endif()

  if(trans_include_detector_WARNINGS_AS_ERRORS)
    check_cxx_compiler_flag("-Wl,--fatal-warnings" LINKER_FATAL_WARNINGS)
    if(LINKER_FATAL_WARNINGS)
      # This is not working consistently, so disabling for now
      # target_link_options(trans_include_detector_options INTERFACE -Wl,--fatal-warnings)
    endif()
  endif()

  if(trans_include_detector_ENABLE_HARDENING AND NOT trans_include_detector_ENABLE_GLOBAL_HARDENING)
    include(cmake/Hardening.cmake)
    if(NOT SUPPORTS_UBSAN 
       OR trans_include_detector_ENABLE_SANITIZER_UNDEFINED
       OR trans_include_detector_ENABLE_SANITIZER_ADDRESS
       OR trans_include_detector_ENABLE_SANITIZER_THREAD
       OR trans_include_detector_ENABLE_SANITIZER_LEAK)
      set(ENABLE_UBSAN_MINIMAL_RUNTIME FALSE)
    else()
      set(ENABLE_UBSAN_MINIMAL_RUNTIME TRUE)
    endif()
    trans_include_detector_enable_hardening(trans_include_detector_options OFF ${ENABLE_UBSAN_MINIMAL_RUNTIME})
  endif()

endmacro()
