#import <Foundation/Foundation.h>
NS_ASSUME_NONNULL_BEGIN
typedef NS_ENUM(NSInteger, CHMOCRMatchMode) { CHMOCRMatchModeExact = 0, CHMOCRMatchModeContains, CHMOCRMatchModeStartsWith };
@interface CHMOCRMatcher : NSObject
+ (BOOL)text:(NSString *)text matchesKeyword:(NSString *)keyword mode:(CHMOCRMatchMode)mode;
+ (BOOL)recognizedLines:(NSArray<NSString *> *)lines containSequence:(NSArray<NSString *> *)keywords mode:(CHMOCRMatchMode)mode;
@end
NS_ASSUME_NONNULL_END
