/*******************************************************************************
 * Copyright (c) 2010, Jean-David Gadina www.xs-labs.com
 * Distributed under the Boost Software License, Version 1.0.
 * 
 * Boost Software License - Version 1.0 - August 17th, 2003
 * 
 * Permission is hereby granted, free of charge, to any person or organization
 * obtaining a copy of the software and accompanying documentation covered by
 * this license (the "Software") to use, reproduce, display, distribute,
 * execute, and transmit the Software, and to prepare derivative works of the
 * Software, and to permit third-parties to whom the Software is furnished to
 * do so, all subject to the following:
 * 
 * The copyright notices in the Software and this entire statement, including
 * the above license grant, this restriction and the following disclaimer,
 * must be included in all copies of the Software, in whole or in part, and
 * all derivative works of the Software, unless such copies or derivative
 * works are solely in the form of machine-executable object code generated by
 * a source language processor.
 * 
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE, TITLE AND NON-INFRINGEMENT. IN NO EVENT
 * SHALL THE COPYRIGHT HOLDERS OR ANYONE DISTRIBUTING THE SOFTWARE BE LIABLE
 * FOR ANY DAMAGES OR OTHER LIABILITY, WHETHER IN CONTRACT, TORT OR OTHERWISE,
 * ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
 * DEALINGS IN THE SOFTWARE.
 ******************************************************************************/

/* $Id$ */

#import <fcntl.h>
#import <asl.h>
#import <unistd.h>
#import "libobjc_log.h"

static NSRecursiveLock * __libobjc_log_lock = nil;

#pragma mark -- Private prototypes

static NSRecursiveLock * __libobjc_log_get_lock( void );
static void __libobjc_logv( char * file, int line, libobjc_log_opt opt, NSString * fmt, va_list args );

#pragma mark -- Public functions

void libobjc_log( char * file, int line, libobjc_log_opt opt, NSString * fmt, ... )
{
    va_list args;
    
    va_start( args, fmt );
    __libobjc_logv( file, line, opt, fmt, args );
    va_end( args );
}

#pragma mark -- Private functions

static NSRecursiveLock * __libobjc_log_get_lock( void )
{
    if( __libobjc_log_lock == nil )
    {
        __libobjc_log_lock = [ NSRecursiveLock new ];
    }
    
    return __libobjc_log_lock;
}

static void __libobjc_logv( char * file, int line, libobjc_log_opt opt, NSString * fmt, va_list args )
{
    int                 pid;
    int                 thread_no;
    NSAutoreleasePool * arp;
    NSDate            * date;
    NSThread          * thread;
    NSString          * thread_name;
    NSString          * thread_descr;
    NSString          * time_str;
    NSString          * msg;
    NSString          * logMsg;
    aslclient           asl;
    
    arp          = [ NSAutoreleasePool new ];
    msg          = [ [ NSString alloc ] initWithFormat: fmt locale: nil arguments: args ];
    pid          = ( int )getpid();
    thread       = [ NSThread currentThread ];
    thread_name  = [ thread name ];
    thread_descr = [ thread description ];
    thread_no    = [ [ thread_descr substringWithRange: NSMakeRange( [ thread_descr length ] - 2, 1 ) ] intValue ];
    
    if( thread_name == nil && [ thread isMainThread ] )
    {
        thread_name = @" - <Main>";
    }
    else if( thread_name == nil )
    {
        thread_name = @" - <Unnamed>";
    }
    else
    {
        thread_name = [ NSString stringWithFormat: @" - %@", thread_name ];
    }
    
    date     = [ NSDate date ];
    time_str = [ date descriptionWithCalendarFormat: @"%Y-%m-%d %H:%M:%S.%F" timeZone: nil locale: nil ];
    logMsg   = [ NSString stringWithFormat:
        @"--------------------------------------------------\n"
        @" Log informations:\n"
        @"--------------------------------------------------\n"
        @"\n"
        @"    - File:    %s\n"
        @"    - Line:    %i\n"
        @"    - PID:     %i\n"
        @"    - Thread:  %i%s\n"
        @"    - Time:    %s\n"
        @"\n"
        @"Message:\n"
        @"\n"
        @"%s\n"
        @"\n",
        file,
        line,
        pid,
        thread_no,
        [ thread_name UTF8String ],
        [ time_str UTF8String ],
        [ msg UTF8String ]
    ];
    
    if( __libobjc_log_lock == nil )
    {
        __libobjc_log_get_lock();
    }
    
    [ __libobjc_log_lock lock ];
    
    asl = asl_open( [ [ [ NSProcessInfo processInfo ] processName ] UTF8String ], "com.apple.console", 0 );
    
    if( opt == LIBOBJC_LOG_OPT_CONSOLE_STANDARD )
    {
        asl_log( asl, NULL, ASL_LEVEL_WARNING, "%s", [ msg UTF8String ] );
    }
    else if( opt != LIBOBJC_LOG_OPT_CONSOLE_IGNORE )
    {
        asl_log( asl, NULL, ASL_LEVEL_WARNING, "%s", [ logMsg UTF8String ] );
    }
    
    asl_close( asl );
    
    fprintf
    (
        stderr,
        "%s",
        [ logMsg UTF8String ]
    );
    
    [ __libobjc_log_lock unlock ];
    [ msg release ];
    [ arp release ];
}
