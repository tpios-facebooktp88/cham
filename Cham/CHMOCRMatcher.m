#import "CHMOCRMatcher.h"
@implementation CHMOCRMatcher
+ (BOOL)text:(NSString *)text matchesKeyword:(NSString *)keyword mode:(CHMOCRMatchMode)mode {
    NSString *candidate = [[text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet] lowercaseString];
    NSString *target = [[keyword stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet] lowercaseString];
    if (candidate.length == 0 || target.length == 0) return NO;
    switch (mode) {
        case CHMOCRMatchModeExact: return [candidate isEqualToString:target];
        case CHMOCRMatchModeContains: return [candidate containsString:target];
        case CHMOCRMatchModeStartsWith: return [candidate hasPrefix:target];
    }
    return NO;
}
+ (BOOL)recognizedLines:(NSArray<NSString *> *)lines containSequence:(NSArray<NSString *> *)keywords mode:(CHMOCRMatchMode)mode {
    if (keywords.count == 0 || lines.count == 0) return NO;
    NSUInteger next = 0;
    for (NSString *line in lines) {
        if ([self text:line matchesKeyword:keywords[next] mode:mode] && ++next == keywords.count) return YES;
    }
    return NO;
}
@end
