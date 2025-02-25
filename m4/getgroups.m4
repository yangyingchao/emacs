# getgroups.m4
# serial 25
dnl Copyright (C) 1996-1997, 1999-2004, 2008-2025 Free Software
dnl Foundation, Inc.
dnl This file is free software; the Free Software Foundation
dnl gives unlimited permission to copy and/or distribute it,
dnl with or without modifications, as long as this notice is preserved.

dnl From Jim Meyering.
dnl A wrapper around AC_FUNC_GETGROUPS.

# This is taken from the following Autoconf patch:
# https://git.savannah.gnu.org/gitweb/?p=autoconf.git;a=commitdiff;h=7fbb553727ed7e0e689a17594b58559ecf3ea6e9
AC_DEFUN([AC_FUNC_GETGROUPS],
[
  AC_REQUIRE([AC_TYPE_GETGROUPS])dnl
  AC_REQUIRE([AC_TYPE_SIZE_T])dnl
  AC_REQUIRE([AC_CANONICAL_HOST])dnl for cross-compiles
  AC_CHECK_FUNC([getgroups])

  # If we don't yet have getgroups, see if it's in -lbsd.
  # This is reported to be necessary on an ITOS 3000WS running SEIUX 3.1.
  gl_saved_LIBS=$LIBS
  if test $ac_cv_func_getgroups = no; then
    AC_CHECK_LIB(bsd, getgroups, [GETGROUPS_LIB=-lbsd])
  fi

  # Run the program to test the functionality of the system-supplied
  # getgroups function only if there is such a function.
  if test $ac_cv_func_getgroups = yes; then
    AC_CACHE_CHECK([for working getgroups], [ac_cv_func_getgroups_works],
      [AC_RUN_IFELSE(
         [AC_LANG_PROGRAM(
            [AC_INCLUDES_DEFAULT],
            [[/* On NeXTstep 3.2, getgroups (0, 0) always fails.  */
              return getgroups (0, 0) == -1;]])
         ],
         [ac_cv_func_getgroups_works=yes],
         [ac_cv_func_getgroups_works=no],
         [case "$host_os" in # ((
                           # Guess yes on glibc systems.
            *-gnu* | gnu*) ac_cv_func_getgroups_works="guessing yes" ;;
                           # Guess yes on musl systems.
            *-musl*)       ac_cv_func_getgroups_works="guessing yes" ;;
                           # If we don't know, obey --enable-cross-guesses.
            *)             ac_cv_func_getgroups_works="$gl_cross_guess_normal" ;;
          esac
         ])
      ])
  else
    ac_cv_func_getgroups_works=no
  fi
  case "$ac_cv_func_getgroups_works" in
    *yes)
      AC_DEFINE([HAVE_GETGROUPS], [1],
        [Define to 1 if your system has a working `getgroups' function.])
      ;;
  esac
  LIBS=$gl_saved_LIBS
])# AC_FUNC_GETGROUPS

AC_DEFUN([gl_FUNC_GETGROUPS],
[
  AC_REQUIRE([AC_TYPE_GETGROUPS])
  AC_REQUIRE([gl_UNISTD_H_DEFAULTS])
  AC_REQUIRE([AC_CANONICAL_HOST]) dnl for cross-compiles

  AC_FUNC_GETGROUPS
  if test $ac_cv_func_getgroups != yes; then
    HAVE_GETGROUPS=0
  else
    if test "$ac_cv_type_getgroups" != gid_t \
       || { case "$ac_cv_func_getgroups_works" in
              *yes) false;;
              *) true;;
            esac
          }; then
      REPLACE_GETGROUPS=1
      AC_DEFINE([GETGROUPS_ZERO_BUG], [1], [Define this to 1 if
        getgroups(0,NULL) does not return the number of groups.])
    else
      dnl Detect Mac OS X and FreeBSD bug; POSIX requires getgroups(-1,ptr)
      dnl to fail.
      AC_CACHE_CHECK([whether getgroups handles negative values],
        [gl_cv_func_getgroups_works],
        [AC_RUN_IFELSE([AC_LANG_PROGRAM([AC_INCLUDES_DEFAULT],
          [[int size = getgroups (0, 0);
            gid_t *list = malloc (size * sizeof *list);
            int result = getgroups (-1, list) != -1;
            free (list);
            return result;]])],
          [gl_cv_func_getgroups_works=yes],
          [gl_cv_func_getgroups_works=no],
          [case "$host_os" in
                            # Guess yes on glibc systems.
             *-gnu* | gnu*) gl_cv_func_getgroups_works="guessing yes" ;;
                            # Guess yes on musl systems.
             *-musl*)       gl_cv_func_getgroups_works="guessing yes" ;;
                            # If we don't know, obey --enable-cross-guesses.
             *)             gl_cv_func_getgroups_works="$gl_cross_guess_normal" ;;
           esac
          ])])
      case "$gl_cv_func_getgroups_works" in
        *yes) ;;
        *) REPLACE_GETGROUPS=1 ;;
      esac
    fi
  fi
  test -n "$GETGROUPS_LIB" && LIBS="$GETGROUPS_LIB $LIBS"
])
