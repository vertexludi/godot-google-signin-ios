@interface JWT_Decode : NSObject

+ (NSDictionary *) decodeWithToken:(NSString *)token;

@end
