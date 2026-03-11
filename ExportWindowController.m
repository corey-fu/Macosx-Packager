////////////////////////////////////////////////////////////////////////////////////
//                                                                                //
// OCSINVENTORY-NG                                                                //
//                                                                                //
// Copyleft Guillaume PROTET 2012                                                 //
// Web : http://www.ocsinventory-ng.org                                           //
//                                                                                //
//                                                                                //
// This code is open source and may be copied and modified as long as the source  //
// code is always made freely available.                                          //
// Please refer to the General Public Licence http://www.gnu.org/                 //
//                                                                                //
////////////////////////////////////////////////////////////////////////////////////


#import "ExportWindowController.h"

#import "Context.h"
#import "ConfigurationWindowController.h"
#import "Configuration.h"


@implementation ExportWindowController


-(id) initWithContext:(Context *)contextObject {
    
    if (self = [super initWithWindowNibName:@"ExportWindow"]) {
        [context release];
        context = [contextObject retain];
        
        configuration = [context configuration];
        configurationWindowController = [context configurationWindowController];
        
        filemgr = [NSFileManager defaultManager];
        
        
        
    }
    return self;
    
}

- (void)awakeFromNib {
    
    //Filling defaults values
    [exportFileName setStringValue:@"ocspackage"];
}


- (IBAction) generatePackage:(id)sender {
    
    NSMutableString *ocsAgentCfgContent = nil;
    NSMutableString *modulesCfgContent;
    NSMutableString *protocolName;
    NSMutableString *launchdCfgFile;
    NSString *serverDir;
    NSString *finalMessageComment;
    
    //No export path filled
    if ( !([[exportPath stringValue] length] > 0 )) {
        [context displayAlert:NSLocalizedString(@"Invalid_export_path", @"Warning about invalid export path") comment:NSLocalizedString(@"Invalid_export_path_comment", @"Warning about invalid export path comment") style:NSAlertStyleCritical];
        return;
    }
    
    //No file name filled
    if ( !([[exportFileName stringValue] length] > 0 )) {
        [context displayAlert:NSLocalizedString(@"Invalid_export_file_name", @"Warning about invalid export file name") comment:NSLocalizedString(@"Invalid_export_file_name_comment", @"Warning about invalid export file name comment") style:NSAlertStyleCritical];
        return;
    }
    
    //Pre-check: export directory must be writable
    if (![filemgr isWritableFileAtPath:[exportPath stringValue]]) {
        [context displayAlert:NSLocalizedString(@"No_write_permission_warn", @"No write permission warning")
                      comment:[NSString stringWithFormat:NSLocalizedString(@"No_write_permission_warn_comment", @"No write permission warning comment"), [exportPath stringValue]]
                        style:NSAlertStyleCritical];
        return;
    }
    
    //Pre-check: source .pkg must exist
    if (![[configuration ocsPkgFilePath] length] || ![filemgr fileExistsAtPath:[configuration ocsPkgFilePath]]) {
        [context displayAlert:NSLocalizedString(@"Source_pkg_not_found_warn", @"Source pkg not found warning")
                      comment:[NSString stringWithFormat:NSLocalizedString(@"Source_pkg_not_found_warn_comment", @"Source pkg not found comment"), [configuration ocsPkgFilePath] ?: @"<not set>"]
                        style:NSAlertStyleCritical];
        return;
    }
    
    
    NSString *pkgFileName = [NSString stringWithFormat:@"%@.pkg",[exportFileName stringValue]];
    NSString *ocsPkgPath = [NSString stringWithFormat:@"%@/%@",[exportPath stringValue],pkgFileName];
    NSString *ocsPkgPluginsPath = [NSString stringWithFormat:@"%@/%@/Contents/Plugins",[exportPath stringValue],pkgFileName];
    NSString *ocsPkgResourcesPath = [NSString stringWithFormat:@"%@/%@/Contents/Resources",[exportPath stringValue],pkgFileName];
    NSString *ocsPkgCfgFilePath = [NSString stringWithFormat:@"%@/%@/Contents/Resources/ocsinventory-agent.cfg",[exportPath stringValue],pkgFileName];
    NSString *ocsPkgModulesFilePath = [NSString stringWithFormat:@"%@/%@/Contents/Resources/modules.conf",[exportPath stringValue],pkgFileName];
    NSString *ocsPkgServerdirFilePath = [NSString stringWithFormat:@"%@/%@/Contents/Resources/serverdir",[exportPath stringValue],pkgFileName];
    NSString *ocsPkgCacertFilePath = [NSString stringWithFormat:@"%@/%@/Contents/Resources/cacert.pem",[exportPath stringValue],pkgFileName];
    NSString *ocsPkgLaunchdFilePath = [NSString stringWithFormat:@"%@/%@/Contents/Resources/org.ocsng.agent.plist",[exportPath stringValue],pkgFileName];
    NSString *ocsPkgNowFilePath = [NSString stringWithFormat:@"%@/%@/Contents/Resources/now",[exportPath stringValue],pkgFileName];
    
    //We check if package already exists
    if ([filemgr fileExistsAtPath:ocsPkgPath]) {
        NSAlert *existsWrn = [[NSAlert alloc] init];
        
        [existsWrn addButtonWithTitle:NSLocalizedString(@"Yes", @"Yes Button")];
        [existsWrn addButtonWithTitle:NSLocalizedString(@"No", @"No Button")];
        [existsWrn setMessageText:[NSString stringWithFormat:NSLocalizedString(@"Package_already_exists_warn",@"Warning about already existing package file"),pkgFileName]];
        [existsWrn setInformativeText:[NSString stringWithFormat:NSLocalizedString(@"Package_already_exists_warn_comment",@"Warning about already existing package file comment"),pkgFileName]];
        [existsWrn setAlertStyle:NSAlertStyleCritical];
        
        if ([existsWrn runModal] != NSAlertFirstButtonReturn) {
            //Button 'No' was clicked, we don't continue
            [existsWrn release];
            return;
        } else {
            //We delete file
            [existsWrn release];
            if(![self removeFile:ocsPkgPath]) {
                [context displayAlert:[NSString stringWithFormat:NSLocalizedString(@"Package_remove_error_warn", @"Warning about package remove error"),pkgFileName] comment:NSLocalizedString(@"Package_remove_error_warn_comment",@"Warning about package remove error comment") style:NSAlertStyleCritical];
                return;
            }
        }
    }
    
    //We create new package  file
    NSError *copyError = nil;
    if (![filemgr copyItemAtPath:[configuration ocsPkgFilePath] toPath:ocsPkgPath error:&copyError]) {
        [context displayAlert:[NSString stringWithFormat:NSLocalizedString(@"Package_copy_error_warn", @"Warning about package copy error"), pkgFileName]
                      comment:[NSString stringWithFormat:@"%@\n%@\nSource: %@\nDestination: %@",
                               NSLocalizedString(@"Package_copy_error_warn_comment", @"Warning about package copy error comment"),
                               [copyError localizedDescription] ?: @"Unknown error",
                               [configuration ocsPkgFilePath],
                               ocsPkgPath]
                        style:NSAlertStyleCritical];
        return;
    }
    
    //We delete plugins directory for future silent installs
    if (![self removeFile:ocsPkgPluginsPath]) {
        [context displayAlert:[NSString stringWithFormat:NSLocalizedString(@"Plugins_remove_error_warn", @"Warning about plugins directory remove error"),pkgFileName] comment:[NSString stringWithFormat:NSLocalizedString(@"Package_write_error_warn_comment",@"Warning about package write error comment"),pkgFileName] style:NSAlertStyleCritical];
        [self removeFile:ocsPkgPath];
        return;
    }
    
    //We copy preinstall and preupgrade scripts
    // Both preinstall and preupgrade use the same source script file
    NSString *preinstallPath = [NSString stringWithFormat:@"%@/preinstall",[[NSBundle mainBundle] resourcePath]];
    
    if ([filemgr fileExistsAtPath:preinstallPath]) {
        // change from copyPath (deprecated) to copyItemAtPath
        NSError *preinstallCopyError = nil;
        if (![filemgr copyItemAtPath:preinstallPath toPath:[NSString stringWithFormat:@"%@/preinstall",ocsPkgResourcesPath] error:&preinstallCopyError]) {
            [context displayAlert:NSLocalizedString(@"Preinstall_copy_error_warn",@"Warning about preinstall copy error")
                          comment:[NSString stringWithFormat:@"%@\n%@\nPath: %@",
                                   [NSString stringWithFormat:NSLocalizedString(@"Package_write_error_warn_comment", @"Warning about package write error comment"), pkgFileName],
                                   [preinstallCopyError localizedDescription] ?: @"Unknown error",
                                   preinstallPath]
                            style:NSAlertStyleCritical];
            [self removeFile:ocsPkgPath];
            return;
        }
        
        // change from copyPath (deprecated) to copyItemAtPath
        NSError *preupgradeCopyError = nil;
        if (![filemgr copyItemAtPath:preinstallPath toPath:[NSString stringWithFormat:@"%@/preupgrade",ocsPkgResourcesPath] error:&preupgradeCopyError]) {
            [context displayAlert:NSLocalizedString(@"Preupgrade_copy_error_warn",@"Warning about preupgrade copy error")
                          comment:[NSString stringWithFormat:@"%@\n%@\nPath: %@",
                                   [NSString stringWithFormat:NSLocalizedString(@"Package_write_error_warn_comment", @"Warning about package write error comment"), pkgFileName],
                                   [preupgradeCopyError localizedDescription] ?: @"Unknown error",
                                   preinstallPath]
                            style:NSAlertStyleCritical];
            [self removeFile:ocsPkgPath];
            return;
        }
    }
    
    //We create agent configuration files
    if ([[configuration server] length] > 0) {
        ocsAgentCfgContent = [@"server=" mutableCopy];
        
        //Adding server value to the mutable string
        [ocsAgentCfgContent appendString:[configuration protocol]];
        [ocsAgentCfgContent appendString:[configuration server]];
        [ocsAgentCfgContent appendString:@"\n"];
        [ocsAgentCfgContent appendString:@"\n"];
    }
    
    if ([[configuration tag] length] > 0) {
        [ocsAgentCfgContent appendString:@"tag="];
        [ocsAgentCfgContent appendString:[configuration tag]];
        [ocsAgentCfgContent appendString:@"\n"];
    }
    
    if ([[configuration logfile] length] > 0) {
        [ocsAgentCfgContent appendString:@"logfile="];
        [ocsAgentCfgContent appendString:[configuration logfile]];
        [ocsAgentCfgContent appendString:@"\n"];
    }
    
    if ([configuration debugmode]) {
        [ocsAgentCfgContent appendString:@"debug=1\n"];
    } else {
        [ocsAgentCfgContent appendString:@"debug=0\n"];
    }
    
    if ([configuration lazy]) {
        [ocsAgentCfgContent appendString:@"lazy=1\n"];
    } else {
        [ocsAgentCfgContent appendString:@"lazy=0\n"];
    }
    
    if ([configuration ssl]) {
        [ocsAgentCfgContent appendString:@"ssl=1\n"];
    } else {
        [ocsAgentCfgContent appendString:@"ssl=0\n"];
    }
    
    if ([configuration authUser]) {
        [ocsAgentCfgContent appendString:@"user="];
        NSData *user = [[configuration authUser] dataUsingEncoding:NSUTF8StringEncoding];
        NSString *userEncoded = [user base64EncodedStringWithOptions:kNilOptions];
        [ocsAgentCfgContent appendString:userEncoded];
        [ocsAgentCfgContent appendString:@"\n"];
    }
    
    if ([configuration authPwd]) {
        [ocsAgentCfgContent appendString:@"password="];
        NSData *pwd = [[configuration authPwd] dataUsingEncoding:NSUTF8StringEncoding];
        NSString *pwdEncoded = [pwd base64EncodedStringWithOptions:kNilOptions];
        [ocsAgentCfgContent appendString:pwdEncoded];
        [ocsAgentCfgContent appendString:@"\n"];
    }
    
    if ([configuration authRealm]) {
        [ocsAgentCfgContent appendString:@"realm="];
        [ocsAgentCfgContent appendString:[configuration authRealm]];
        [ocsAgentCfgContent appendString:@"\n"];
    }
    
    
    NSError *cfgWriteError = nil;
    if(![ocsAgentCfgContent writeToFile:ocsPkgCfgFilePath atomically: YES encoding:NSUTF8StringEncoding error:&cfgWriteError]) {
        [context displayAlert:NSLocalizedString(@"Configuration_file_write_error_warn",@"Warning about ocsinventory-agent.cfg file write error")
                      comment:[NSString stringWithFormat:@"%@\n%@",
                               [NSString stringWithFormat:NSLocalizedString(@"Package_write_error_warn_comment", @"Warning about package write error comment"), pkgFileName],
                               [cfgWriteError localizedDescription] ?: @"Unknown error"]
                        style:NSAlertStyleCritical];
        [self removeFile:ocsPkgPath];
        return;
    }
    
    //We create modules configuration files
    modulesCfgContent = [@"# this list of module will be load by the at run time\n"
                         @"# to check its syntax do:\n"
                         @"# #perl modules.conf\n"
                         @"# You must have NO error. Else the content will be ignored\n"
                         @"# This mechanism goal it to keep compatibility with 'plugin'\n"
                         @"# created for the previous linux_agent.\n"
                         @"# The new unified_agent have its own extension system that allow\n"
                         @"# user to add new information easily.\n"
                         @"\n"
                         @"#use Ocsinventory::Agent::Modules::Example;\n"
                         mutableCopy];
    
    if ( [configuration download] == 1) {
        [modulesCfgContent appendString:@"use Ocsinventory::Agent::Modules::Download;\n"];
    } else {
        [modulesCfgContent appendString:@"#use Ocsinventory::Agent::Modules::Download;\n"];
    }
    
    [modulesCfgContent appendString:@"\n"
     @"# DO NOT REMOVE THE 1;\n"
     @"1;"
     ];
    
    NSError *modulesCfgWriteError = nil;
    if (![modulesCfgContent writeToFile:ocsPkgModulesFilePath atomically: YES encoding:NSUTF8StringEncoding error:&modulesCfgWriteError]) {
        [context displayAlert:NSLocalizedString(@"Modules_file_write_error_warn",@"Warning about modules.conf file write error")
                      comment:[NSString stringWithFormat:@"%@\n%@",
                               [NSString stringWithFormat:NSLocalizedString(@"Package_write_error_warn_comment", @"Warning about package write error comment"), pkgFileName],
                               [modulesCfgWriteError localizedDescription] ?: @"Unknown error"]
                        style:NSAlertStyleCritical];
        [self removeFile:ocsPkgPath];
        return;
    }
    
    
    //We copy cacertfile and create file for server directory creation
    if ([[configuration cacertFilePath] length] > 0) {
        
        protocolName = [[configuration protocol] mutableCopy];
        [protocolName replaceOccurrencesOfString:@"/" withString:@"" options:NSCaseInsensitiveSearch range:NSMakeRange(0, [protocolName length])];
        
        serverDir = [NSString stringWithFormat:@"/var/lib/ocsinventory-agent/%@__%@_ocsinventory", protocolName, [configuration server]];
        NSError *serverDirWriteError = nil;
        // serverdir is informational; a write failure is non-fatal — the agent can still run without it
        [serverDir writeToFile:ocsPkgServerdirFilePath atomically: YES encoding:NSUTF8StringEncoding error:&serverDirWriteError];
        if (serverDirWriteError) {
            NSLog(@"Warning: could not write serverdir file at %@: %@", ocsPkgServerdirFilePath, [serverDirWriteError localizedDescription]);
        }
        
        // change from copyPath (deprecated) to copyItemAtPath
        NSError *cacertCopyError = nil;
        if (![filemgr copyItemAtPath:[configuration cacertFilePath] toPath:ocsPkgCacertFilePath error:&cacertCopyError]) {
            [context displayAlert:NSLocalizedString(@"Cacert_file_copy_error_warn",@"Warning about cacert.pem file copy error")
                          comment:[NSString stringWithFormat:@"%@\n%@\nSource: %@",
                                   [NSString stringWithFormat:NSLocalizedString(@"Package_write_error_warn_comment", @"Warning about package write error comment"), pkgFileName],
                                   [cacertCopyError localizedDescription] ?: @"Unknown error",
                                   [configuration cacertFilePath]]
                            style:NSAlertStyleCritical];
            [self removeFile:ocsPkgPath];
            return;
        }
    }
    
    
    //We create launchd configuration file
    //TODO: use XML parser instead of writing the XML as a simple text file ?
    launchdCfgFile = [@"<?xml version='1.0' encoding='UTF-8'?>\n"
                      @"<!DOCTYPE plist PUBLIC '-//Apple//DTD PLIST 1.0//EN' 'http://www.apple.com/DTDs/PropertyList-1.0.dtd'>\n"
                      @"<plist version='1.0'>\n"
                      @"<dict>\n"
                      @"\t<key>Label</key>\n"
                      @"\t<string>org.ocsng.agent</string>\n"
                      @"\t<key>ProgramArguments</key>\n"
                      @"\t\t<array>\n"
                      @"\t\t\t<string>/Applications/OCSNG.app/Contents/MacOS/OCSNG</string>\n"
                      @"\t\t</array>\n"
                      mutableCopy];
    
    
    if ([configuration startup] == 1) {
        [launchdCfgFile  appendString:@"\t<key>RunAtLoad</key>\n"
         @"\t<true/>\n"
         ];
    }
    
    if ( [[configuration periodicity] length] > 0) {
        //We convert string to numeric value and check if it is integer
        NSNumberFormatter *formatter = [[NSNumberFormatter alloc] init];
        NSNumber *convert = [formatter numberFromString:[configuration periodicity]];
        [formatter release];
        
        if (convert) {
            int hours = [convert intValue];
            int seconds =  hours * 3600;
            
            [launchdCfgFile  appendString:@"\t<key>StartInterval</key>\n"
             @"\t<integer>"
             ];
            
            [launchdCfgFile  appendString:[NSString stringWithFormat:@"%d", seconds]];
            [launchdCfgFile  appendString:@"</integer>\n"];
            
        } else {
            //Invalid periodificty value
            [context displayAlert:NSLocalizedString(@"Periodicity_warn", @"Peridocity warn") comment:NSLocalizedString(@"Periodicity_warn_comment", @"Periodicity warn comment") style:NSAlertStyleCritical];
            [self removeFile:ocsPkgPath];
            return;
        }
    }
    
    [launchdCfgFile appendString:@"</dict>\n"
     @"</plist>"
     ];
    
    NSError *launchdWriteError = nil;
    if (![launchdCfgFile writeToFile:ocsPkgLaunchdFilePath atomically: YES encoding:NSUTF8StringEncoding error:&launchdWriteError]) {
        [context displayAlert:NSLocalizedString(@"Launchd_file_write_error_warn",@"Warning about org.ocsng.agent.plit file write error")
                      comment:[NSString stringWithFormat:@"%@\n%@",
                               [NSString stringWithFormat:NSLocalizedString(@"Package_write_error_warn_comment", @"Warning about package write error comment"), pkgFileName],
                               [launchdWriteError localizedDescription] ?: @"Unknown error"]
                        style:NSAlertStyleCritical];
        [self removeFile:ocsPkgPath];
        return;
    }
    
    
    //We create now file if needed
    if ([configuration now] == 1) {
        if (![filemgr createFileAtPath:ocsPkgNowFilePath contents:nil attributes:nil]) {
            [context displayAlert:NSLocalizedString(@"Now_file_write_error_warn",@"Warning about now file write error") comment:[NSString stringWithFormat:NSLocalizedString(@"Package_write_error_warn_comment", @"Warning about package write error comment"),pkgFileName] style:NSAlertStyleCritical];
            [self removeFile:ocsPkgPath];
            return;
        }
    }
    
    
    //Everything OK and package generated succefully
    finalMessageComment = [NSString stringWithFormat:NSLocalizedString(@"Package_succesfully_created_comment",@"Message for succefull created package_comment"), pkgFileName, [exportPath stringValue]];
    [context displayAlert:NSLocalizedString(@"Package_succesfully_created",@"Message for succefull created package") comment:finalMessageComment style:NSAlertStyleInformational];
    [NSApp terminate:self];
}


//To quit application
- (IBAction) terminateApp:(id)sender {
    [NSApp terminate:self];
}

- (IBAction) backConfigurationWindow:(id)sender {
    
    [[configurationWindowController window] orderFront:sender];
    [[self window] orderOut:sender];
}

- (IBAction) chooseExportPath:(id)sender {
    
    //Configuration for the browse panel
    NSOpenPanel *panel = [NSOpenPanel openPanel];
    [panel setCanChooseDirectories:YES];
    [panel setCanChooseFiles:NO];
    [panel setAllowsMultipleSelection:NO];
    
    
    //Running browse panel
    NSInteger result = [panel runModal];
    
    //Getting cacert file path
    if (result == NSModalResponseOK) {
        [exportPath setStringValue:[[panel URL] path]];
    }
}

- (BOOL) removeFile:(NSString *)path {
    BOOL returnValue = YES;
    
    if ([filemgr fileExistsAtPath:path]) {
        // change from removeFileAtPath (deprecated) to removeItemAtPAth
        NSError *removeError = nil;
        returnValue = [filemgr removeItemAtPath:path error:&removeError];
        if (!returnValue && removeError) {
            NSLog(@"Error removing file at path %@: %@", path, [removeError localizedDescription]);
        }
    }
    
    return returnValue;
}


//Famous dealloc for memory management
- (void) dealloc {
    [context release];
    [super dealloc];
    
}

@end
