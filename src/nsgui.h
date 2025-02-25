/* Definitions and headers for communication on the NeXT/Open/GNUstep API.
   Copyright (C) 1995, 2005, 2008-2025 Free Software Foundation, Inc.

This file is part of GNU Emacs.

GNU Emacs is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or (at
your option) any later version.

GNU Emacs is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with GNU Emacs.  If not, see <https://www.gnu.org/licenses/>.  */

#ifndef __NSGUI_H__
#define __NSGUI_H__

/* This gets included from a couple of the plain (non-NS) .c files.  */
#ifdef __OBJC__

#ifdef NS_IMPL_COCOA
#ifdef Z
#warning "Z is defined.  If you get a later parse error in a header, check that buffer.h or other files #define-ing Z are not included."
#endif  /* Z */
#define Cursor FooFoo
#endif  /* NS_IMPL_COCOA */

#undef verify

#import <AppKit/AppKit.h>

#ifdef NS_IMPL_COCOA
#undef Cursor
#endif /* NS_IMPL_COCOA */
#import <Foundation/NSDistantObject.h>

#ifdef NS_IMPL_COCOA
#include <AvailabilityMacros.h>
#endif /* NS_IMPL_COCOA */

#endif /* __OBJC__ */

#undef verify
#undef _GL_VERIFY_H
#include <verify.h>

/* Emulate XCharStruct.  */
typedef struct _XCharStruct
{
  int rbearing;
  int lbearing;
  int width;
  int ascent;
  int descent;
} XCharStruct;

#ifdef __OBJC__
typedef id Emacs_Pixmap;
#else
typedef void *Emacs_Pixmap;
#endif

#ifdef __OBJC__
typedef NSCursor *Emacs_Cursor;
#else
typedef void *Emacs_Cursor;
#endif

typedef int Window;

#ifndef __OBJC__
#if defined (__LP64__) && __LP64__
typedef double CGFloat;
#else
typedef float CGFloat;
#endif
typedef struct _NSPoint { CGFloat x, y; } NSPoint;
typedef struct _NSSize  { CGFloat width, height; } NSSize;
typedef struct _NSRect  { NSPoint origin; NSSize size; } NSRect;
#endif  /* NOT OBJC */

#define NativeRectangle NSRect

#define CONVERT_TO_EMACS_RECT(xr, nr)		\
  ((xr).x     = (nr).origin.x,			\
   (xr).y     = (nr).origin.y,			\
   (xr).width = (nr).size.width,		\
   (xr).height = (nr).size.height)

#define CONVERT_FROM_EMACS_RECT(xr, nr)		\
  ((nr).origin.x    = (xr).x,			\
   (nr).origin.y    = (xr).y,			\
   (nr).size.width  = (xr).width,		\
   (nr).size.height = (xr).height)

#define STORE_NATIVE_RECT(nr, px, py, pwidth, pheight)	\
  ((nr).origin.x    = (px),			\
   (nr).origin.y    = (py),			\
   (nr).size.width  = (pwidth),			\
   (nr).size.height = (pheight))




/* This stuff needed by frame.c.  */
#define ForgetGravity		0
#define NorthWestGravity	1
#define NorthGravity		2
#define NorthEastGravity	3
#define WestGravity		4
#define CenterGravity		5
#define EastGravity		6
#define SouthWestGravity	7
#define SouthGravity		8
#define SouthEastGravity	9
#define StaticGravity		10

#define NoValue		0x0000
#define XValue  	0x0001
#define YValue		0x0002
#define WidthValue  	0x0004
#define HeightValue  	0x0008
#define AllValues 	0x000F
#define XNegative 	0x0010
#define YNegative 	0x0020

#define USPosition	(1L << 0) /* user specified x, y */
#define USSize		(1L << 1) /* user specified width, height */

#define PPosition	(1L << 2) /* program specified position */
#define PSize		(1L << 3) /* program specified size */
#define PMinSize	(1L << 4) /* program specified minimum size */
#define PMaxSize	(1L << 5) /* program specified maximum size */
#define PResizeInc	(1L << 6) /* program specified resize increments */
#define PAspect		(1L << 7) /* program specified min, max aspect ratios */
#define PBaseSize	(1L << 8) /* program specified base for incrementing */
#define PWinGravity	(1L << 9) /* program specified window gravity */

#endif  /* __NSGUI_H__ */
