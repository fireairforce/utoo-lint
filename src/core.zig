const std = @import("std");
const parser = @import("parser");

const ast = parser.ast;
const Allocator = std.mem.Allocator;

pub const Severity = enum {
    @"error",
    warning,

    pub fn toString(self: Severity) []const u8 {
        return switch (self) {
            .@"error" => "error",
            .warning => "warning",
        };
    }
};

pub const EqeqeqStyle = enum {
    strict,
    allow_null,
    smart,
};

pub const CurlyStyle = enum {
    all,
    multi_line,
    multi,
};

pub const ObjectShorthandStyle = enum {
    always,
    methods,
    properties,
    never,
};

pub const OperatorAssignmentStyle = enum {
    always,
    never,
};

pub const LinebreakStyle = enum {
    unix,
    windows,
};

pub const EolLastStyle = enum {
    always,
    never,
};

pub const UnicodeBomStyle = enum {
    never,
    always,
};

pub const NoCondAssignStyle = enum {
    except_parens,
    always,
};

pub const NoLabelsAllowLoop = enum {
    yes,
    no,
};

pub const NoLabelsAllowSwitch = enum {
    yes,
    no,
};

pub const NoConfusingArrowAllowParens = enum {
    yes,
    no,
};

pub const max_no_console_allow_methods = 32;
pub const max_no_console_allow_method_len = 128;

pub const NoConsoleAllow = struct {
    count: usize = 0,
    lengths: [max_no_console_allow_methods]usize = undefined,
    storage: [max_no_console_allow_methods][max_no_console_allow_method_len]u8 = undefined,

    pub fn contains(self: NoConsoleAllow, name: []const u8) bool {
        for (0..self.count) |index| {
            if (std.mem.eql(u8, self.at(index), name)) return true;
        }
        return false;
    }

    pub fn at(self: *const NoConsoleAllow, index: usize) []const u8 {
        return self.storage[index][0..self.lengths[index]];
    }

    pub fn enable(self: *NoConsoleAllow, name: []const u8) bool {
        if (name.len == 0 or name.len > max_no_console_allow_method_len) return false;
        if (self.contains(name)) return true;
        if (self.count >= max_no_console_allow_methods) return false;

        @memcpy(self.storage[self.count][0..name.len], name);
        self.lengths[self.count] = name.len;
        self.count += 1;
        return true;
    }
};

pub const NoEmptyAllowEmptyCatch = enum {
    yes,
    no,
};

pub const NoEmptyFunctionAllow = struct {
    functions: bool = false,
    arrowFunctions: bool = false,
    generatorFunctions: bool = false,
    asyncFunctions: bool = false,
    methods: bool = false,
    generatorMethods: bool = false,
    asyncMethods: bool = false,
    getters: bool = false,
    setters: bool = false,
    constructors: bool = false,

    pub fn contains(self: NoEmptyFunctionAllow, name: []const u8) bool {
        inline for (@typeInfo(NoEmptyFunctionAllow).@"struct".fields) |field| {
            if (std.mem.eql(u8, field.name, name)) return @field(self, field.name);
        }
        return false;
    }

    pub fn enable(self: *NoEmptyFunctionAllow, name: []const u8) bool {
        inline for (@typeInfo(NoEmptyFunctionAllow).@"struct".fields) |field| {
            if (std.mem.eql(u8, field.name, name)) {
                @field(self, field.name) = true;
                return true;
            }
        }
        return false;
    }
};

pub const NoFallthroughAllowEmptyCase = enum {
    yes,
    no,
};

pub const NoInvalidRegexpAllowConstructorFlags = struct {
    flags: [256]bool = [_]bool{false} ** 256,

    pub fn contains(self: NoInvalidRegexpAllowConstructorFlags, flag: u8) bool {
        return self.flags[flag];
    }

    pub fn enable(self: *NoInvalidRegexpAllowConstructorFlags, flag: []const u8) bool {
        if (flag.len != 1) return false;
        self.flags[flag[0]] = true;
        return true;
    }
};

pub const NoInnerDeclarationsMode = enum {
    functions,
    both,
};

pub const NoMultiSpacesIgnoreEOLComments = enum {
    yes,
    no,
};

pub const NoMultiSpacesExceptions = struct {
    property: bool = true,
    binary_expression: bool = false,
    variable_declarator: bool = false,
    import_declaration: bool = false,
};

pub const NoReturnAssignStyle = enum {
    except_parens,
    always,
};

pub const RadixStyle = enum {
    always,
    as_needed,
};

pub const NoSequencesAllowInParentheses = enum {
    yes,
    no,
};

pub const NoUnderscoreDangleAllowFunctionParams = enum {
    yes,
    no,
};

pub const NoUnderscoreDangleAllowDestructuring = enum {
    yes,
    no,
};

pub const NoWarningCommentsLocation = enum {
    start,
    anywhere,
};

pub const NoWarningCommentsDecoration = enum {
    none,
    asterisk,
    slash,
    slash_asterisk,
};

pub const no_warning_comments_default_terms = [_][]const u8{
    "todo",
    "fixme",
    "xxx",
};

pub const max_no_warning_comments_terms = 32;
pub const max_no_warning_comments_term_len = 128;

pub const NoWarningCommentsTermsError = error{
    EmptyNoWarningCommentsTerm,
    TooManyNoWarningCommentsTerms,
    NoWarningCommentsTermTooLong,
};

pub const NoWarningCommentsTerms = struct {
    custom: bool = false,
    count: usize = 0,
    lengths: [max_no_warning_comments_terms]usize = undefined,
    storage: [max_no_warning_comments_terms][max_no_warning_comments_term_len]u8 = undefined,

    pub fn len(self: *const NoWarningCommentsTerms) usize {
        return if (self.custom) self.count else no_warning_comments_default_terms.len;
    }

    pub fn at(self: *const NoWarningCommentsTerms, index: usize) []const u8 {
        if (!self.custom) return no_warning_comments_default_terms[index];
        return self.storage[index][0..self.lengths[index]];
    }

    pub fn set(self: *NoWarningCommentsTerms, terms: []const []const u8) NoWarningCommentsTermsError!void {
        self.custom = true;
        self.count = 0;
        for (terms) |term| try self.append(term);
    }

    pub fn append(self: *NoWarningCommentsTerms, term: []const u8) NoWarningCommentsTermsError!void {
        if (term.len == 0) return error.EmptyNoWarningCommentsTerm;
        if (self.count >= max_no_warning_comments_terms) return error.TooManyNoWarningCommentsTerms;
        if (term.len > max_no_warning_comments_term_len) return error.NoWarningCommentsTermTooLong;

        self.custom = true;
        @memcpy(self.storage[self.count][0..term.len], term);
        self.lengths[self.count] = term.len;
        self.count += 1;
    }
};

pub const SpacedCommentStyle = enum {
    always,
    never,
};

pub const max_spaced_comment_markers = 32;
pub const max_spaced_comment_marker_len = 32;

pub const SpacedCommentMarkersError = error{
    EmptySpacedCommentMarker,
    TooManySpacedCommentMarkers,
    SpacedCommentMarkerTooLong,
};

pub const SpacedCommentMarkers = struct {
    count: usize = 0,
    lengths: [max_spaced_comment_markers]usize = undefined,
    storage: [max_spaced_comment_markers][max_spaced_comment_marker_len]u8 = undefined,

    pub fn matches(self: *const SpacedCommentMarkers, value: []const u8) bool {
        for (0..self.count) |index| {
            if (std.mem.startsWith(u8, value, self.at(index))) return true;
        }
        return false;
    }

    pub fn at(self: *const SpacedCommentMarkers, index: usize) []const u8 {
        return self.storage[index][0..self.lengths[index]];
    }

    pub fn append(self: *SpacedCommentMarkers, marker: []const u8) SpacedCommentMarkersError!void {
        if (marker.len == 0) return error.EmptySpacedCommentMarker;
        if (self.count >= max_spaced_comment_markers) return error.TooManySpacedCommentMarkers;
        if (marker.len > max_spaced_comment_marker_len) return error.SpacedCommentMarkerTooLong;

        @memcpy(self.storage[self.count][0..marker.len], marker);
        self.lengths[self.count] = marker.len;
        self.count += 1;
    }
};

pub const NoVoidAllowAsStatement = enum {
    yes,
    no,
};

pub const NoImplicitCoercionBoolean = enum {
    yes,
    no,
};

pub const NoImplicitCoercionNumber = enum {
    yes,
    no,
};

pub const NoImplicitCoercionString = enum {
    yes,
    no,
};

pub const NoPlusplusAllowForLoopAfterthoughts = enum {
    yes,
    no,
};

pub const NoRedeclareBuiltinGlobals = enum {
    yes,
    no,
};

pub const NoUnusedExpressionsAllowShortCircuit = enum {
    yes,
    no,
};

pub const NoUnusedExpressionsAllowTernary = enum {
    yes,
    no,
};

pub const NoUnusedExpressionsAllowTaggedTemplates = enum {
    yes,
    no,
};

pub const NoUseBeforeDefineCheck = enum {
    yes,
    no,
};

pub const NoShadowHoist = enum {
    all,
    functions,
    functions_and_types,
    never,
    types,
};

pub const NoUnusedVarsVars = enum {
    all,
    local,
};

pub const NoUnusedVarsArgs = enum {
    none,
    after_used,
    all,
};

pub const NoUnusedVarsCaughtErrors = enum {
    none,
    all,
};

pub const NoParamReassignProps = enum {
    yes,
    no,
};

pub const max_no_param_reassign_ignored_names = 32;
pub const max_no_param_reassign_ignored_name_len = 128;
pub const max_no_param_reassign_ignored_name_patterns = 32;
pub const max_no_param_reassign_ignored_name_pattern_len = 256;

pub const NoParamReassignIgnoredNamesError = error{
    EmptyNoParamReassignIgnoredName,
    TooManyNoParamReassignIgnoredNames,
    NoParamReassignIgnoredNameTooLong,
};

pub const NoParamReassignIgnoredNames = struct {
    count: usize = 0,
    lengths: [max_no_param_reassign_ignored_names]usize = undefined,
    storage: [max_no_param_reassign_ignored_names][max_no_param_reassign_ignored_name_len]u8 = undefined,

    pub fn contains(self: *const NoParamReassignIgnoredNames, name: []const u8) bool {
        for (0..self.count) |index| {
            if (std.mem.eql(u8, self.at(index), name)) return true;
        }
        return false;
    }

    pub fn at(self: *const NoParamReassignIgnoredNames, index: usize) []const u8 {
        return self.storage[index][0..self.lengths[index]];
    }

    pub fn append(self: *NoParamReassignIgnoredNames, name: []const u8) NoParamReassignIgnoredNamesError!void {
        if (name.len == 0) return error.EmptyNoParamReassignIgnoredName;
        if (self.count >= max_no_param_reassign_ignored_names) return error.TooManyNoParamReassignIgnoredNames;
        if (name.len > max_no_param_reassign_ignored_name_len) return error.NoParamReassignIgnoredNameTooLong;

        @memcpy(self.storage[self.count][0..name.len], name);
        self.lengths[self.count] = name.len;
        self.count += 1;
    }
};

pub const NoParamReassignIgnoredNamePatternsError = error{
    EmptyNoParamReassignIgnoredNamePattern,
    TooManyNoParamReassignIgnoredNamePatterns,
    NoParamReassignIgnoredNamePatternTooLong,
};

pub const NoParamReassignIgnoredNamePatterns = struct {
    count: usize = 0,
    lengths: [max_no_param_reassign_ignored_name_patterns]usize = undefined,
    storage: [max_no_param_reassign_ignored_name_patterns][max_no_param_reassign_ignored_name_pattern_len]u8 = undefined,

    pub fn at(self: *const NoParamReassignIgnoredNamePatterns, index: usize) []const u8 {
        return self.storage[index][0..self.lengths[index]];
    }

    pub fn append(self: *NoParamReassignIgnoredNamePatterns, pattern: []const u8) NoParamReassignIgnoredNamePatternsError!void {
        if (pattern.len == 0) return error.EmptyNoParamReassignIgnoredNamePattern;
        if (self.count >= max_no_param_reassign_ignored_name_patterns) return error.TooManyNoParamReassignIgnoredNamePatterns;
        if (pattern.len > max_no_param_reassign_ignored_name_pattern_len) return error.NoParamReassignIgnoredNamePatternTooLong;

        @memcpy(self.storage[self.count][0..pattern.len], pattern);
        self.lengths[self.count] = pattern.len;
        self.count += 1;
    }
};

pub const max_no_extend_native_exceptions = 32;
pub const max_no_extend_native_exception_len = 128;

pub const NoExtendNativeExceptionsError = error{
    EmptyNoExtendNativeException,
    TooManyNoExtendNativeExceptions,
    NoExtendNativeExceptionTooLong,
};

pub const NoExtendNativeExceptions = struct {
    count: usize = 0,
    lengths: [max_no_extend_native_exceptions]usize = undefined,
    storage: [max_no_extend_native_exceptions][max_no_extend_native_exception_len]u8 = undefined,

    pub fn contains(self: *const NoExtendNativeExceptions, name: []const u8) bool {
        for (0..self.count) |index| {
            if (std.mem.eql(u8, self.at(index), name)) return true;
        }
        return false;
    }

    pub fn at(self: *const NoExtendNativeExceptions, index: usize) []const u8 {
        return self.storage[index][0..self.lengths[index]];
    }

    pub fn append(self: *NoExtendNativeExceptions, name: []const u8) NoExtendNativeExceptionsError!void {
        if (name.len == 0) return error.EmptyNoExtendNativeException;
        if (self.count >= max_no_extend_native_exceptions) return error.TooManyNoExtendNativeExceptions;
        if (name.len > max_no_extend_native_exception_len) return error.NoExtendNativeExceptionTooLong;

        @memcpy(self.storage[self.count][0..name.len], name);
        self.lengths[self.count] = name.len;
        self.count += 1;
    }
};

pub const max_no_shadow_allow_names = 32;
pub const max_no_shadow_allow_name_len = 128;

pub const NoShadowAllowNamesError = error{
    EmptyNoShadowAllowName,
    TooManyNoShadowAllowNames,
    NoShadowAllowNameTooLong,
};

pub const NoShadowAllowNames = struct {
    count: usize = 0,
    lengths: [max_no_shadow_allow_names]usize = undefined,
    storage: [max_no_shadow_allow_names][max_no_shadow_allow_name_len]u8 = undefined,

    pub fn contains(self: *const NoShadowAllowNames, name: []const u8) bool {
        for (0..self.count) |index| {
            if (std.mem.eql(u8, self.at(index), name)) return true;
        }
        return false;
    }

    pub fn at(self: *const NoShadowAllowNames, index: usize) []const u8 {
        return self.storage[index][0..self.lengths[index]];
    }

    pub fn append(self: *NoShadowAllowNames, name: []const u8) NoShadowAllowNamesError!void {
        if (name.len == 0) return error.EmptyNoShadowAllowName;
        if (self.count >= max_no_shadow_allow_names) return error.TooManyNoShadowAllowNames;
        if (name.len > max_no_shadow_allow_name_len) return error.NoShadowAllowNameTooLong;

        @memcpy(self.storage[self.count][0..name.len], name);
        self.lengths[self.count] = name.len;
        self.count += 1;
    }
};

pub const max_no_unused_vars_ignore_pattern_len = 256;

pub const NoUnusedVarsIgnorePatternError = error{
    NoUnusedVarsIgnorePatternTooLong,
};

pub const NoUnusedVarsIgnorePattern = struct {
    custom: bool = false,
    length: usize = 0,
    storage: [max_no_unused_vars_ignore_pattern_len]u8 = undefined,

    pub fn pattern(self: *const NoUnusedVarsIgnorePattern) ?[]const u8 {
        if (!self.custom) return null;
        return self.storage[0..self.length];
    }

    pub fn set(self: *NoUnusedVarsIgnorePattern, pattern_value: []const u8) NoUnusedVarsIgnorePatternError!void {
        if (pattern_value.len > max_no_unused_vars_ignore_pattern_len) return error.NoUnusedVarsIgnorePatternTooLong;
        @memcpy(self.storage[0..pattern_value.len], pattern_value);
        self.custom = true;
        self.length = pattern_value.len;
    }
};

pub const max_no_useless_escape_allow_regex_characters = 32;

pub const NoUselessEscapeAllowRegexCharactersError = error{
    EmptyNoUselessEscapeAllowRegexCharacter,
    TooManyNoUselessEscapeAllowRegexCharacters,
    NoUselessEscapeAllowRegexCharacterTooLong,
};

pub const NoUselessEscapeAllowRegexCharacters = struct {
    count: usize = 0,
    characters: [max_no_useless_escape_allow_regex_characters]u8 = undefined,

    pub fn contains(self: *const NoUselessEscapeAllowRegexCharacters, character: u8) bool {
        for (0..self.count) |index| {
            if (self.characters[index] == character) return true;
        }
        return false;
    }

    pub fn append(self: *NoUselessEscapeAllowRegexCharacters, character: []const u8) NoUselessEscapeAllowRegexCharactersError!void {
        if (character.len == 0) return error.EmptyNoUselessEscapeAllowRegexCharacter;
        if (character.len > 1) return error.NoUselessEscapeAllowRegexCharacterTooLong;
        if (self.count >= max_no_useless_escape_allow_regex_characters) return error.TooManyNoUselessEscapeAllowRegexCharacters;

        self.characters[self.count] = character[0];
        self.count += 1;
    }
};

pub const max_no_this_alias_allowed_names = 32;
pub const max_no_this_alias_allowed_name_len = 128;

pub const NoThisAliasAllowedNamesError = error{
    EmptyNoThisAliasAllowedName,
    TooManyNoThisAliasAllowedNames,
    NoThisAliasAllowedNameTooLong,
};

pub const NoThisAliasAllowedNames = struct {
    custom: bool = false,
    count: usize = 0,
    lengths: [max_no_this_alias_allowed_names]usize = undefined,
    storage: [max_no_this_alias_allowed_names][max_no_this_alias_allowed_name_len]u8 = undefined,

    pub fn contains(self: *const NoThisAliasAllowedNames, name: []const u8) bool {
        if (!self.custom) return std.mem.eql(u8, name, "self");

        for (0..self.count) |index| {
            if (std.mem.eql(u8, self.at(index), name)) return true;
        }
        return false;
    }

    pub fn at(self: *const NoThisAliasAllowedNames, index: usize) []const u8 {
        return self.storage[index][0..self.lengths[index]];
    }

    pub fn append(self: *NoThisAliasAllowedNames, name: []const u8) NoThisAliasAllowedNamesError!void {
        if (name.len == 0) return error.EmptyNoThisAliasAllowedName;
        if (self.count >= max_no_this_alias_allowed_names) return error.TooManyNoThisAliasAllowedNames;
        if (name.len > max_no_this_alias_allowed_name_len) return error.NoThisAliasAllowedNameTooLong;

        @memcpy(self.storage[self.count][0..name.len], name);
        self.lengths[self.count] = name.len;
        self.count += 1;
    }
};

pub const max_react_jsx_pascal_case_ignore_names = 32;
pub const max_react_jsx_pascal_case_ignore_name_len = 128;

pub const react_jsx_filename_extension_default_extensions = [_][]const u8{
    ".jsx",
    ".js",
    ".tsx",
    ".ts",
    ".vue",
};

pub const max_react_jsx_filename_extensions = 16;
pub const max_react_jsx_filename_extension_len = 32;

pub const ReactJsxFilenameExtensionsError = error{
    EmptyReactJsxFilenameExtension,
    TooManyReactJsxFilenameExtensions,
    ReactJsxFilenameExtensionTooLong,
};

pub const ReactJsxFilenameExtensions = struct {
    custom: bool = false,
    count: usize = 0,
    lengths: [max_react_jsx_filename_extensions]usize = undefined,
    storage: [max_react_jsx_filename_extensions][max_react_jsx_filename_extension_len]u8 = undefined,

    pub fn len(self: *const ReactJsxFilenameExtensions) usize {
        return if (self.custom) self.count else react_jsx_filename_extension_default_extensions.len;
    }

    pub fn at(self: *const ReactJsxFilenameExtensions, index: usize) []const u8 {
        if (!self.custom) return react_jsx_filename_extension_default_extensions[index];
        return self.storage[index][0..self.lengths[index]];
    }

    pub fn containsFilePath(self: *const ReactJsxFilenameExtensions, file_path: []const u8) bool {
        for (0..self.len()) |index| {
            if (std.mem.endsWith(u8, file_path, self.at(index))) return true;
        }
        return false;
    }

    pub fn append(self: *ReactJsxFilenameExtensions, extension_name: []const u8) ReactJsxFilenameExtensionsError!void {
        if (extension_name.len == 0) return error.EmptyReactJsxFilenameExtension;
        if (self.count >= max_react_jsx_filename_extensions) return error.TooManyReactJsxFilenameExtensions;
        if (extension_name.len > max_react_jsx_filename_extension_len) return error.ReactJsxFilenameExtensionTooLong;

        self.custom = true;
        @memcpy(self.storage[self.count][0..extension_name.len], extension_name);
        self.lengths[self.count] = extension_name.len;
        self.count += 1;
    }
};

pub const ReactJsxPascalCaseIgnoreNamesError = error{
    EmptyReactJsxPascalCaseIgnoreName,
    TooManyReactJsxPascalCaseIgnoreNames,
    ReactJsxPascalCaseIgnoreNameTooLong,
};

pub const ReactJsxPascalCaseIgnoreNames = struct {
    count: usize = 0,
    lengths: [max_react_jsx_pascal_case_ignore_names]usize = undefined,
    storage: [max_react_jsx_pascal_case_ignore_names][max_react_jsx_pascal_case_ignore_name_len]u8 = undefined,

    pub fn contains(self: *const ReactJsxPascalCaseIgnoreNames, name: []const u8) bool {
        for (0..self.count) |index| {
            if (std.mem.eql(u8, self.at(index), name)) return true;
        }
        return false;
    }

    pub fn at(self: *const ReactJsxPascalCaseIgnoreNames, index: usize) []const u8 {
        return self.storage[index][0..self.lengths[index]];
    }

    pub fn append(self: *ReactJsxPascalCaseIgnoreNames, name: []const u8) ReactJsxPascalCaseIgnoreNamesError!void {
        if (name.len == 0) return error.EmptyReactJsxPascalCaseIgnoreName;
        if (self.count >= max_react_jsx_pascal_case_ignore_names) return error.TooManyReactJsxPascalCaseIgnoreNames;
        if (name.len > max_react_jsx_pascal_case_ignore_name_len) return error.ReactJsxPascalCaseIgnoreNameTooLong;

        @memcpy(self.storage[self.count][0..name.len], name);
        self.lengths[self.count] = name.len;
        self.count += 1;
    }
};

pub const max_react_no_unknown_property_ignore_names = 32;
pub const max_react_no_unknown_property_ignore_name_len = 128;

pub const ReactNoUnknownPropertyIgnoreNamesError = error{
    EmptyReactNoUnknownPropertyIgnoreName,
    TooManyReactNoUnknownPropertyIgnoreNames,
    ReactNoUnknownPropertyIgnoreNameTooLong,
};

pub const ReactNoUnknownPropertyIgnoreNames = struct {
    count: usize = 0,
    lengths: [max_react_no_unknown_property_ignore_names]usize = undefined,
    storage: [max_react_no_unknown_property_ignore_names][max_react_no_unknown_property_ignore_name_len]u8 = undefined,

    pub fn contains(self: *const ReactNoUnknownPropertyIgnoreNames, name: []const u8) bool {
        for (0..self.count) |index| {
            if (std.mem.eql(u8, self.at(index), name)) return true;
        }
        return false;
    }

    pub fn at(self: *const ReactNoUnknownPropertyIgnoreNames, index: usize) []const u8 {
        return self.storage[index][0..self.lengths[index]];
    }

    pub fn append(self: *ReactNoUnknownPropertyIgnoreNames, name: []const u8) ReactNoUnknownPropertyIgnoreNamesError!void {
        if (name.len == 0) return error.EmptyReactNoUnknownPropertyIgnoreName;
        if (self.count >= max_react_no_unknown_property_ignore_names) return error.TooManyReactNoUnknownPropertyIgnoreNames;
        if (name.len > max_react_no_unknown_property_ignore_name_len) return error.ReactNoUnknownPropertyIgnoreNameTooLong;

        @memcpy(self.storage[self.count][0..name.len], name);
        self.lengths[self.count] = name.len;
        self.count += 1;
    }
};

pub const max_typescript_eslint_ban_type_entries = 32;
pub const max_typescript_eslint_ban_type_name_len = 128;
pub const max_typescript_eslint_ban_type_message_len = 512;

pub const TypescriptEslintBanTypesConfigError = error{
    EmptyBanTypeName,
    BanTypeNameTooLong,
    BanTypeMessageTooLong,
    TooManyBanTypes,
};

pub const TypescriptEslintBanTypeNames = struct {
    count: usize = 0,
    lengths: [max_typescript_eslint_ban_type_entries]usize = undefined,
    storage: [max_typescript_eslint_ban_type_entries][max_typescript_eslint_ban_type_name_len]u8 = undefined,

    pub fn contains(self: *const TypescriptEslintBanTypeNames, name: []const u8) bool {
        for (0..self.count) |index| {
            if (std.mem.eql(u8, self.at(index), name)) return true;
        }
        return false;
    }

    pub fn at(self: *const TypescriptEslintBanTypeNames, index: usize) []const u8 {
        return self.storage[index][0..self.lengths[index]];
    }

    pub fn append(self: *TypescriptEslintBanTypeNames, name: []const u8) TypescriptEslintBanTypesConfigError!void {
        if (name.len == 0) return error.EmptyBanTypeName;
        if (name.len > max_typescript_eslint_ban_type_name_len) return error.BanTypeNameTooLong;
        if (self.count >= max_typescript_eslint_ban_type_entries) return error.TooManyBanTypes;

        @memcpy(self.storage[self.count][0..name.len], name);
        self.lengths[self.count] = name.len;
        self.count += 1;
    }
};

pub const TypescriptEslintBanTypeEntries = struct {
    count: usize = 0,
    name_lengths: [max_typescript_eslint_ban_type_entries]usize = undefined,
    message_lengths: [max_typescript_eslint_ban_type_entries]usize = undefined,
    names: [max_typescript_eslint_ban_type_entries][max_typescript_eslint_ban_type_name_len]u8 = undefined,
    messages: [max_typescript_eslint_ban_type_entries][max_typescript_eslint_ban_type_message_len]u8 = undefined,

    pub fn messageFor(self: *const TypescriptEslintBanTypeEntries, name: []const u8) ?[]const u8 {
        var index = self.count;
        while (index > 0) {
            index -= 1;
            if (std.mem.eql(u8, self.nameAt(index), name)) return self.messageAt(index);
        }
        return null;
    }

    pub fn nameAt(self: *const TypescriptEslintBanTypeEntries, index: usize) []const u8 {
        return self.names[index][0..self.name_lengths[index]];
    }

    pub fn messageAt(self: *const TypescriptEslintBanTypeEntries, index: usize) []const u8 {
        return self.messages[index][0..self.message_lengths[index]];
    }

    pub fn append(
        self: *TypescriptEslintBanTypeEntries,
        name: []const u8,
        message: []const u8,
    ) TypescriptEslintBanTypesConfigError!void {
        if (name.len == 0) return error.EmptyBanTypeName;
        if (name.len > max_typescript_eslint_ban_type_name_len) return error.BanTypeNameTooLong;
        if (message.len > max_typescript_eslint_ban_type_message_len) return error.BanTypeMessageTooLong;
        if (self.count >= max_typescript_eslint_ban_type_entries) return error.TooManyBanTypes;

        @memcpy(self.names[self.count][0..name.len], name);
        @memcpy(self.messages[self.count][0..message.len], message);
        self.name_lengths[self.count] = name.len;
        self.message_lengths[self.count] = message.len;
        self.count += 1;
    }
};

pub const TypescriptEslintBanTypesConfig = struct {
    extend_defaults: bool = true,
    disabled: TypescriptEslintBanTypeNames = .{},
    custom: TypescriptEslintBanTypeEntries = .{},
};

pub const max_new_cap_exception_names = 32;
pub const max_new_cap_exception_name_len = 128;

pub const NewCapExceptionNamesError = error{
    EmptyNewCapExceptionName,
    TooManyNewCapExceptionNames,
    NewCapExceptionNameTooLong,
};

pub const NewCapExceptionNames = struct {
    count: usize = 0,
    lengths: [max_new_cap_exception_names]usize = undefined,
    storage: [max_new_cap_exception_names][max_new_cap_exception_name_len]u8 = undefined,

    pub fn contains(self: *const NewCapExceptionNames, name: []const u8) bool {
        for (0..self.count) |index| {
            if (std.mem.eql(u8, self.at(index), name)) return true;
        }
        return false;
    }

    pub fn at(self: *const NewCapExceptionNames, index: usize) []const u8 {
        return self.storage[index][0..self.lengths[index]];
    }

    pub fn append(self: *NewCapExceptionNames, name: []const u8) NewCapExceptionNamesError!void {
        if (name.len == 0) return error.EmptyNewCapExceptionName;
        if (self.count >= max_new_cap_exception_names) return error.TooManyNewCapExceptionNames;
        if (name.len > max_new_cap_exception_name_len) return error.NewCapExceptionNameTooLong;

        @memcpy(self.storage[self.count][0..name.len], name);
        self.lengths[self.count] = name.len;
        self.count += 1;
    }
};

pub const max_new_cap_exception_pattern_len = 256;

pub const NewCapExceptionPatternError = error{
    NewCapExceptionPatternTooLong,
};

pub const NewCapExceptionPattern = struct {
    custom: bool = false,
    length: usize = 0,
    storage: [max_new_cap_exception_pattern_len]u8 = undefined,

    pub fn pattern(self: *const NewCapExceptionPattern) ?[]const u8 {
        if (!self.custom) return null;
        return self.storage[0..self.length];
    }

    pub fn set(self: *NewCapExceptionPattern, pattern_value: []const u8) NewCapExceptionPatternError!void {
        if (pattern_value.len > max_new_cap_exception_pattern_len) return error.NewCapExceptionPatternTooLong;
        @memcpy(self.storage[0..pattern_value.len], pattern_value);
        self.custom = true;
        self.length = pattern_value.len;
    }
};

pub const NoUselessComputedKeyEnforceForClassMembers = enum {
    yes,
    no,
};

pub const WrapIifeStyle = enum {
    outside,
    inside,
    any,
};

pub const AccessorPairsGetWithoutSet = enum {
    yes,
    no,
};

pub const AccessorPairsSetWithoutGet = enum {
    yes,
    no,
};

pub const AccessorPairsEnforceForClassMembers = enum {
    yes,
    no,
};

pub const GroupedAccessorPairsStyle = enum {
    any_order,
    get_before_set,
    set_before_get,
};

pub const LogicalAssignmentOperatorsEnforceForIfStatements = enum {
    yes,
    no,
};

pub const LogicalAssignmentOperatorsStyle = enum {
    always,
    never,
};

pub const ReactJsxBooleanValueStyle = enum {
    never,
    always,
};

pub const ReactPreferEs6ClassStyle = enum {
    always,
    never,
};

pub const FuncNamesStyle = enum {
    always,
    as_needed,
    never,
};

pub const FuncNameMatchingStyle = enum {
    always,
    never,
};

pub const NoConstantConditionCheckLoops = enum {
    all,
    all_except_while_true,
    none,
};

pub const YodaStyle = enum {
    never,
    always,
};

pub const TypescriptEslintMethodSignatureStyle = enum {
    property,
    method,
};

pub const TypescriptEslintArrayTypeStyle = enum {
    array,
    array_simple,
    generic,
};

pub const TypescriptEslintBanTsCommentMode = enum {
    allow,
    ban,
    allow_with_description,
};

pub const TypescriptEslintConsistentTypeDefinitionsStyle = enum {
    interface,
    type,
};

pub const TypescriptEslintClassLiteralPropertyStyle = enum {
    fields,
    getters,
};

pub const TypescriptEslintConsistentTypeAssertionsStyle = enum {
    as,
    angle_bracket,
    never,
};

pub const TypescriptEslintLiteralTypeAssertions = enum {
    allow,
    allow_as_parameter,
    never,
};

pub const TypescriptEslintExplicitMemberAccessibility = enum {
    explicit,
    no_public,
    off,
};

pub const TypescriptEslintTripleSlashReferenceMode = enum {
    always,
    never,
};

pub const PreferConstDestructuring = enum {
    any,
    all,
};

pub const ArrayCallbackReturnAllowImplicit = enum {
    yes,
    no,
};

pub const ArrayCallbackReturnCheckForEach = enum {
    yes,
    no,
};

pub const ArrayCallbackReturnAllowVoid = enum {
    yes,
    no,
};

pub const CapitalizedCommentsMode = enum {
    always,
    never,
};

pub const CapitalizedCommentsIgnoreInlineComments = enum {
    yes,
    no,
};

pub const CapitalizedCommentsIgnoreConsecutiveComments = enum {
    yes,
    no,
};

pub const DotNotationAllowKeywords = enum {
    yes,
    no,
};

pub const max_no_inline_comments_ignore_pattern_len = 256;

pub const NoInlineCommentsIgnorePatternError = error{
    NoInlineCommentsIgnorePatternTooLong,
};

pub const NoInlineCommentsIgnorePattern = struct {
    custom: bool = false,
    length: usize = 0,
    storage: [max_no_inline_comments_ignore_pattern_len]u8 = undefined,

    pub fn pattern(self: *const NoInlineCommentsIgnorePattern) ?[]const u8 {
        if (!self.custom) return null;
        return self.storage[0..self.length];
    }

    pub fn set(self: *NoInlineCommentsIgnorePattern, pattern_value: []const u8) NoInlineCommentsIgnorePatternError!void {
        if (pattern_value.len > max_no_inline_comments_ignore_pattern_len) return error.NoInlineCommentsIgnorePatternTooLong;
        @memcpy(self.storage[0..pattern_value.len], pattern_value);
        self.custom = true;
        self.length = pattern_value.len;
    }
};

pub const max_dot_notation_allow_pattern_len = 256;

pub const DotNotationAllowPatternError = error{
    DotNotationAllowPatternTooLong,
};

pub const DotNotationAllowPattern = struct {
    custom: bool = false,
    length: usize = 0,
    storage: [max_dot_notation_allow_pattern_len]u8 = undefined,

    pub fn pattern(self: *const DotNotationAllowPattern) ?[]const u8 {
        if (!self.custom) return null;
        return self.storage[0..self.length];
    }

    pub fn set(self: *DotNotationAllowPattern, pattern_value: []const u8) DotNotationAllowPatternError!void {
        if (pattern_value.len > max_dot_notation_allow_pattern_len) return error.DotNotationAllowPatternTooLong;
        @memcpy(self.storage[0..pattern_value.len], pattern_value);
        self.custom = true;
        self.length = pattern_value.len;
    }
};

pub const max_default_case_comment_pattern_len = 256;

pub const DefaultCaseCommentPatternError = error{
    DefaultCaseCommentPatternTooLong,
};

pub const DefaultCaseCommentPattern = struct {
    custom: bool = false,
    length: usize = 0,
    storage: [max_default_case_comment_pattern_len]u8 = undefined,

    pub fn pattern(self: *const DefaultCaseCommentPattern) ?[]const u8 {
        if (!self.custom) return null;
        return self.storage[0..self.length];
    }

    pub fn set(self: *DefaultCaseCommentPattern, pattern_value: []const u8) DefaultCaseCommentPatternError!void {
        if (pattern_value.len > max_default_case_comment_pattern_len) return error.DefaultCaseCommentPatternTooLong;
        @memcpy(self.storage[0..pattern_value.len], pattern_value);
        self.custom = true;
        self.length = pattern_value.len;
    }
};

pub const max_no_fallthrough_comment_pattern_len = 256;

pub const NoFallthroughCommentPatternError = error{
    NoFallthroughCommentPatternTooLong,
};

pub const NoFallthroughCommentPattern = struct {
    custom: bool = false,
    length: usize = 0,
    storage: [max_no_fallthrough_comment_pattern_len]u8 = undefined,

    pub fn pattern(self: *const NoFallthroughCommentPattern) ?[]const u8 {
        if (!self.custom) return null;
        return self.storage[0..self.length];
    }

    pub fn set(self: *NoFallthroughCommentPattern, pattern_value: []const u8) NoFallthroughCommentPatternError!void {
        if (pattern_value.len > max_no_fallthrough_comment_pattern_len) return error.NoFallthroughCommentPatternTooLong;
        @memcpy(self.storage[0..pattern_value.len], pattern_value);
        self.custom = true;
        self.length = pattern_value.len;
    }
};

pub const Options = struct {
    accessor_pairs: bool = true,
    accessor_pairs_get_without_set: AccessorPairsGetWithoutSet = .no,
    accessor_pairs_set_without_get: AccessorPairsSetWithoutGet = .yes,
    accessor_pairs_enforce_for_class_members: AccessorPairsEnforceForClassMembers = .yes,
    array_callback_return: bool = true,
    array_callback_return_allow_implicit: ArrayCallbackReturnAllowImplicit = .no,
    array_callback_return_check_for_each: ArrayCallbackReturnCheckForEach = .no,
    array_callback_return_allow_void: ArrayCallbackReturnAllowVoid = .no,
    block_scoped_var: bool = true,
    capitalized_comments: bool = true,
    capitalized_comments_mode: CapitalizedCommentsMode = .always,
    capitalized_comments_ignore_inline_comments: CapitalizedCommentsIgnoreInlineComments = .no,
    capitalized_comments_ignore_consecutive_comments: CapitalizedCommentsIgnoreConsecutiveComments = .no,
    consistent_return: bool = true,
    consistent_return_treat_undefined_as_unspecified: bool = false,
    constructor_super: bool = true,
    curly: bool = true,
    curly_style: CurlyStyle = .all,
    dot_notation: bool = true,
    dot_notation_allow_keywords: DotNotationAllowKeywords = .yes,
    dot_notation_allow_pattern: DotNotationAllowPattern = .{},
    typescript_eslint_dot_notation: bool = true,
    default_case: bool = true,
    default_case_comment_pattern: DefaultCaseCommentPattern = .{},
    default_case_last: bool = true,
    default_param_last: bool = true,
    eol_last: bool = true,
    eol_last_style: EolLastStyle = .always,
    eslint_comments_no_restricted_disable: bool = true,
    eslint_comments_no_restricted_disable_no_nested_ternary: bool = false,
    for_direction: bool = true,
    func_name_matching: bool = true,
    func_name_matching_style: FuncNameMatchingStyle = .always,
    func_names: bool = true,
    func_names_style: FuncNamesStyle = .always,
    func_names_has_generator_style: bool = false,
    func_names_generator_style: FuncNamesStyle = .always,
    getter_return: bool = true,
    grouped_accessor_pairs: bool = true,
    grouped_accessor_pairs_style: GroupedAccessorPairsStyle = .any_order,
    guard_for_in: bool = true,
    linebreak_style: bool = true,
    linebreak_style_style: LinebreakStyle = .unix,
    logical_assignment_operators: bool = true,
    logical_assignment_operators_style: LogicalAssignmentOperatorsStyle = .always,
    logical_assignment_operators_enforce_for_if_statements: LogicalAssignmentOperatorsEnforceForIfStatements = .no,
    new_cap: bool = true,
    new_cap_new_is_cap: bool = true,
    new_cap_cap_is_new: bool = true,
    new_cap_properties: bool = true,
    new_cap_new_is_cap_exceptions: NewCapExceptionNames = .{},
    new_cap_cap_is_new_exceptions: NewCapExceptionNames = .{},
    new_cap_new_is_cap_exception_pattern: NewCapExceptionPattern = .{},
    new_cap_cap_is_new_exception_pattern: NewCapExceptionPattern = .{},
    new_parens: bool = true,
    no_async_promise_executor: bool = true,
    no_array_constructor: bool = true,
    no_await_in_loop: bool = true,
    no_alert: bool = true,
    no_bitwise: bool = true,
    no_bitwise_allow_bitwise_and: bool = false,
    no_bitwise_allow_bitwise_or: bool = false,
    no_bitwise_allow_bitwise_xor: bool = false,
    no_bitwise_allow_bitwise_not: bool = false,
    no_bitwise_allow_left_shift: bool = false,
    no_bitwise_allow_right_shift: bool = false,
    no_bitwise_allow_unsigned_right_shift: bool = false,
    no_bitwise_int32_hint: bool = false,
    no_buffer_constructor: bool = true,
    no_caller: bool = true,
    no_case_declarations: bool = true,
    no_class_assign: bool = true,
    no_confusing_arrow: bool = true,
    no_confusing_arrow_allow_parens: NoConfusingArrowAllowParens = .yes,
    no_cond_assign: bool = true,
    no_cond_assign_style: NoCondAssignStyle = .except_parens,
    no_compare_neg_zero: bool = true,
    no_constant_condition: bool = true,
    no_constant_condition_check_loops: NoConstantConditionCheckLoops = .all_except_while_true,
    no_const_assign: bool = true,
    no_control_regex: bool = true,
    no_console: bool = true,
    no_console_allow: NoConsoleAllow = .{},
    no_comma_operator: bool = true,
    no_continue: bool = true,
    no_constructor_return: bool = true,
    no_debugger: bool = true,
    no_dupe_else_if: bool = true,
    no_duplicate_case: bool = true,
    no_dupe_args: bool = true,
    no_dupe_class_members: bool = true,
    typescript_eslint_no_dupe_class_members: bool = true,
    no_dupe_keys: bool = true,
    no_duplicate_imports: bool = true,
    no_duplicate_imports_allow_separate_type_imports: bool = false,
    no_delete_var: bool = true,
    no_div_regex: bool = true,
    no_empty: bool = true,
    no_empty_allow_empty_catch: NoEmptyAllowEmptyCatch = .no,
    no_empty_block_statements: bool = true,
    no_empty_character_class: bool = true,
    no_empty_function: bool = true,
    no_empty_function_allow: NoEmptyFunctionAllow = .{},
    no_empty_pattern: bool = true,
    no_empty_pattern_allow_object_patterns_as_parameters: bool = false,
    no_empty_static_block: bool = true,
    no_else_return: bool = true,
    no_else_return_allow_else_if: bool = true,
    no_eq_null: bool = true,
    no_eval: bool = true,
    no_eval_allow_indirect: bool = false,
    no_ex_assign: bool = true,
    no_extend_native: bool = true,
    no_extend_native_exceptions: NoExtendNativeExceptions = .{},
    no_extra_bind: bool = true,
    no_extra_label: bool = true,
    no_extra_semi: bool = true,
    no_extra_boolean_cast: bool = true,
    no_extra_boolean_cast_enforce_for_inner_expressions: bool = false,
    no_floating_decimal: bool = true,
    no_fallthrough: bool = true,
    no_fallthrough_allow_empty_case: NoFallthroughAllowEmptyCase = .no,
    no_fallthrough_comment_pattern: NoFallthroughCommentPattern = .{},
    no_fallthrough_report_unused_fallthrough_comment: bool = false,
    no_for_in: bool = true,
    no_func_assign: bool = true,
    no_global_assign: bool = true,
    no_global_assign_exceptions: NoShadowAllowNames = .{},
    no_global_is_finite: bool = true,
    no_global_is_nan: bool = true,
    no_implicit_coercion: bool = true,
    no_implicit_coercion_boolean: NoImplicitCoercionBoolean = .yes,
    no_implicit_coercion_number: NoImplicitCoercionNumber = .yes,
    no_implicit_coercion_string: NoImplicitCoercionString = .yes,
    no_implicit_coercion_allow_double_negation: bool = false,
    no_implicit_coercion_allow_bitwise_not: bool = false,
    no_implicit_coercion_allow_plus: bool = false,
    no_implicit_coercion_allow_multiply: bool = false,
    no_implicit_coercion_allow_subtract: bool = false,
    no_implicit_coercion_allow_double_negative: bool = false,
    no_implicit_coercion_disallow_template_shorthand: bool = false,
    no_implied_eval: bool = true,
    no_import_assign: bool = true,
    alipay_ant_disallow_typos: bool = true,
    alipay_ant_exhaustive_deps: bool = true,
    alipay_ant_jsx_handler_names: bool = true,
    alipay_ant_no_deprecated_dependence: bool = true,
    alipay_ant_no_deprecated_dependence_profile: DeprecatedDependenceProfile = .default,
    alipay_ant_no_deprecated_variable: bool = true,
    alipay_ant_no_import_files_from_pages_in_common: bool = true,
    alipay_ant_no_negative_conditionals: bool = true,
    alipay_ant_no_import_src: bool = true,
    alipay_ant_no_phantom_dependencies: bool = true,
    alipay_ant_no_too_large_file: bool = true,
    alipay_ant_prefer_elseif_end_with_else: bool = true,
    alipay_ant_prefer_catch_unsafe_func_call: bool = true,
    alipay_ant_prefer_click_with_debounce: bool = true,
    alipay_ant_prefer_import_as_required: bool = true,
    alipay_ant_no_spread_params: bool = true,
    alipay_ant_prefer_managed_resource: bool = true,
    alipay_ant_prefer_safe_image_renderer: bool = true,
    alipay_ant_prefer_import_from_stdlib: bool = true,
    alipay_spmlint_use_labeled_spm: bool = true,
    alipay_spmlint_valid_manual_click: bool = true,
    alipay_spmlint_valid_manual_expo: bool = true,
    alipay_spmlint_valid_manual_param: bool = true,
    alipay_spmlint_valid_manual_pv: bool = true,
    import_default: bool = true,
    import_export: bool = true,
    import_first: bool = true,
    import_named: bool = true,
    import_namespace: bool = true,
    import_newline_after_import: bool = true,
    import_newline_after_import_count: usize = 1,
    import_newline_after_import_exact_count: bool = false,
    import_no_amd: bool = true,
    import_no_cycle: bool = true,
    import_no_duplicates: bool = true,
    import_no_named_as_default: bool = true,
    import_no_named_as_default_member: bool = true,
    import_no_unresolved: bool = true,
    import_no_self_import: bool = true,
    jsx_a11y_alt_text: bool = true,
    jsx_a11y_anchor_has_content: bool = true,
    jsx_a11y_aria_props: bool = true,
    jsx_a11y_aria_proptypes: bool = true,
    jsx_a11y_aria_role: bool = true,
    jsx_a11y_aria_unsupported_elements: bool = true,
    jsx_a11y_iframe_has_title: bool = true,
    jsx_a11y_img_redundant_alt: bool = true,
    jsx_a11y_no_access_key: bool = true,
    jsx_a11y_no_distracting_elements: bool = true,
    jsx_a11y_role_has_required_aria_props: bool = true,
    jsx_a11y_role_supports_aria_props: bool = true,
    jsx_a11y_scope: bool = true,
    no_invalid_regexp: bool = true,
    no_invalid_regexp_allow_constructor_flags: NoInvalidRegexpAllowConstructorFlags = .{},
    no_irregular_whitespace: bool = true,
    no_irregular_whitespace_skip_strings: bool = true,
    no_irregular_whitespace_skip_comments: bool = false,
    no_irregular_whitespace_skip_reg_exps: bool = false,
    no_irregular_whitespace_skip_templates: bool = false,
    no_irregular_whitespace_skip_jsx_text: bool = false,
    no_inline_comments: bool = true,
    no_inline_comments_ignore_pattern: NoInlineCommentsIgnorePattern = .{},
    no_inner_declarations: bool = true,
    no_inner_declarations_mode: NoInnerDeclarationsMode = .functions,
    no_iterator: bool = true,
    no_label_var: bool = true,
    no_labels: bool = true,
    no_labels_allow_loop: NoLabelsAllowLoop = .no,
    no_labels_allow_switch: NoLabelsAllowSwitch = .no,
    no_lone_blocks: bool = true,
    no_lonely_if: bool = true,
    no_loop_func: bool = true,
    no_loss_of_precision: bool = true,
    no_multi_str: bool = true,
    no_multi_assign: bool = true,
    no_multi_assign_ignore_non_declaration: bool = false,
    no_multi_spaces: bool = true,
    no_multi_spaces_ignore_eol_comments: NoMultiSpacesIgnoreEOLComments = .no,
    no_multi_spaces_exceptions: NoMultiSpacesExceptions = .{},
    no_mixed_spaces_and_tabs: bool = true,
    no_mixed_spaces_and_tabs_smart_tabs: bool = false,
    no_misleading_character_class: bool = true,
    no_multiple_empty_lines: bool = true,
    no_multiple_empty_lines_max: usize = 2,
    no_multiple_empty_lines_max_bof: ?usize = null,
    no_multiple_empty_lines_max_eof: ?usize = null,
    no_nonoctal_decimal_escape: bool = true,
    no_new: bool = true,
    no_nested_ternary: bool = true,
    no_negated_condition: bool = true,
    no_new_native_nonconstructor: bool = true,
    no_new_func: bool = true,
    no_new_require: bool = true,
    no_obj_calls: bool = true,
    no_new_object: bool = true,
    no_new_symbol: bool = true,
    no_new_wrappers: bool = true,
    no_octal: bool = true,
    no_octal_escape: bool = true,
    no_object_constructor: bool = true,
    no_param_reassign: bool = true,
    no_param_reassign_props: NoParamReassignProps = .no,
    no_param_reassign_ignore_property_modifications_for: NoParamReassignIgnoredNames = .{},
    no_param_reassign_ignore_property_modifications_for_regex: NoParamReassignIgnoredNamePatterns = .{},
    no_path_concat: bool = true,
    no_plusplus: bool = true,
    no_plusplus_allow_for_loop_afterthoughts: NoPlusplusAllowForLoopAfterthoughts = .no,
    no_promise_executor_return: bool = true,
    no_promise_executor_return_allow_void: bool = false,
    no_proto: bool = true,
    no_process_env: bool = true,
    no_process_exit: bool = true,
    no_prototype_builtins: bool = true,
    no_redeclare: bool = true,
    no_redeclare_builtin_globals: NoRedeclareBuiltinGlobals = .no,
    no_regex_spaces: bool = true,
    no_return_await: bool = true,
    no_return_assign: bool = true,
    no_return_assign_style: NoReturnAssignStyle = .except_parens,
    no_useless_return: bool = true,
    no_script_url: bool = true,
    no_self_assign: bool = true,
    no_self_assign_props: bool = true,
    no_self_compare: bool = true,
    no_setter_return: bool = true,
    no_shadow: bool = true,
    no_shadow_allow: NoShadowAllowNames = .{},
    no_shadow_builtin_globals: bool = false,
    no_shadow_hoist: NoShadowHoist = .functions,
    no_shadow_ignore_on_initialization: bool = false,
    no_shadow_restricted_names: bool = true,
    no_sequences: bool = true,
    no_sequences_allow_in_parentheses: NoSequencesAllowInParentheses = .yes,
    no_sparse_arrays: bool = true,
    no_ternary: bool = true,
    no_template_curly_in_string: bool = true,
    no_throw_literal: bool = true,
    no_this_before_super: bool = true,
    no_tabs: bool = true,
    no_tabs_allow_indentation_tabs: bool = false,
    no_trailing_spaces: bool = true,
    no_trailing_spaces_skip_blank_lines: bool = false,
    no_trailing_spaces_ignore_comments: bool = false,
    no_unreachable: bool = true,
    no_undef_init: bool = true,
    no_underscore_dangle: bool = true,
    no_underscore_dangle_allow_after_this: bool = false,
    no_underscore_dangle_allow_after_super: bool = false,
    no_underscore_dangle_allow_after_this_constructor: bool = false,
    no_underscore_dangle_allow_function_params: NoUnderscoreDangleAllowFunctionParams = .yes,
    no_underscore_dangle_allow_in_array_destructuring: NoUnderscoreDangleAllowDestructuring = .yes,
    no_underscore_dangle_allow_in_object_destructuring: NoUnderscoreDangleAllowDestructuring = .yes,
    no_underscore_dangle_enforce_in_method_names: bool = false,
    no_underscore_dangle_enforce_in_class_fields: bool = false,
    no_underscore_dangle_allow: NoShadowAllowNames = .{},
    no_undefined: bool = true,
    unicode_bom: bool = true,
    no_unneeded_ternary: bool = true,
    no_unneeded_ternary_default_assignment: bool = true,
    no_unused_labels: bool = true,
    no_unsafe_finally: bool = true,
    no_unsafe_negation: bool = true,
    no_unsafe_negation_enforce_for_ordering_relations: bool = false,
    no_useless_computed_key: bool = true,
    no_useless_computed_key_enforce_for_class_members: NoUselessComputedKeyEnforceForClassMembers = .yes,
    no_useless_call: bool = true,
    no_useless_concat: bool = true,
    no_useless_constructor: bool = true,
    no_useless_catch: bool = true,
    no_useless_escape: bool = true,
    no_useless_escape_allow_regex_characters: NoUselessEscapeAllowRegexCharacters = .{},
    no_useless_rename: bool = true,
    no_useless_rename_ignore_destructuring: bool = false,
    no_useless_rename_ignore_import: bool = false,
    no_useless_rename_ignore_export: bool = false,
    no_unused_expressions: bool = true,
    no_unused_expressions_allow_short_circuit: NoUnusedExpressionsAllowShortCircuit = .no,
    no_unused_expressions_allow_ternary: NoUnusedExpressionsAllowTernary = .no,
    no_unused_expressions_allow_tagged_templates: NoUnusedExpressionsAllowTaggedTemplates = .no,
    typescript_eslint_no_unused_expressions: bool = true,
    typescript_eslint_no_unused_expressions_allow_short_circuit: NoUnusedExpressionsAllowShortCircuit = .yes,
    typescript_eslint_no_unused_expressions_allow_ternary: NoUnusedExpressionsAllowTernary = .yes,
    typescript_eslint_no_unused_expressions_allow_tagged_templates: NoUnusedExpressionsAllowTaggedTemplates = .yes,
    no_warning_comments: bool = true,
    no_warning_comments_location: NoWarningCommentsLocation = .start,
    no_warning_comments_decoration: NoWarningCommentsDecoration = .none,
    no_warning_comments_terms: NoWarningCommentsTerms = .{},
    no_void: bool = true,
    no_void_allow_as_statement: NoVoidAllowAsStatement = .no,
    no_with: bool = true,
    no_var: bool = true,
    unicode_bom_style: UnicodeBomStyle = .never,
    object_shorthand: bool = true,
    object_shorthand_style: ObjectShorthandStyle = .always,
    object_shorthand_avoid_quotes: bool = false,
    object_shorthand_ignore_constructors: bool = false,
    object_shorthand_avoid_explicit_return_arrows: bool = false,
    one_var: bool = true,
    one_var_check_var: bool = true,
    one_var_check_let: bool = true,
    one_var_check_const: bool = true,
    operator_assignment: bool = true,
    operator_assignment_style: OperatorAssignmentStyle = .always,
    eqeqeq: bool = true,
    eqeqeq_style: EqeqeqStyle = .strict,
    use_isnan: bool = true,
    use_isnan_enforce_for_index_of: bool = false,
    use_isnan_enforce_for_switch_case: bool = true,
    no_unused_vars: bool = true,
    no_unused_vars_vars: NoUnusedVarsVars = .all,
    no_unused_vars_args: NoUnusedVarsArgs = .none,
    no_unused_vars_caught_errors: NoUnusedVarsCaughtErrors = .all,
    no_unused_vars_ignore_rest_siblings: bool = false,
    no_unused_vars_ignore_class_with_static_init_block: bool = false,
    no_unused_vars_ignore_using_declarations: bool = false,
    no_unused_vars_args_ignore_pattern: NoUnusedVarsIgnorePattern = .{},
    no_unused_vars_caught_errors_ignore_pattern: NoUnusedVarsIgnorePattern = .{},
    no_unused_vars_destructured_array_ignore_pattern: NoUnusedVarsIgnorePattern = .{},
    no_unused_vars_report_used_ignore_pattern: bool = false,
    no_unused_vars_vars_ignore_pattern: NoUnusedVarsIgnorePattern = .{},
    no_use_before_define: bool = true,
    no_use_before_define_check_functions: NoUseBeforeDefineCheck = .yes,
    no_use_before_define_check_classes: NoUseBeforeDefineCheck = .yes,
    no_use_before_define_check_variables: NoUseBeforeDefineCheck = .yes,
    no_use_before_define_allow_named_exports: bool = false,
    no_undef: bool = true,
    no_undef_typeof: bool = false,
    prefer_const: bool = true,
    prefer_const_destructuring: PreferConstDestructuring = .any,
    prefer_const_ignore_read_before_assign: bool = true,
    prefer_exponentiation_operator: bool = true,
    prefer_numeric_literals: bool = true,
    prefer_object_has_own: bool = true,
    prefer_promise_reject_errors: bool = true,
    prefer_promise_reject_errors_allow_empty_reject: bool = false,
    prefer_destructuring: bool = true,
    prefer_destructuring_variable_declarator_array: bool = true,
    prefer_destructuring_variable_declarator_object: bool = true,
    prefer_destructuring_assignment_expression_array: bool = true,
    prefer_destructuring_assignment_expression_object: bool = true,
    prefer_destructuring_enforce_for_renamed_properties: bool = false,
    prefer_regex_literals: bool = true,
    prefer_regex_literals_disallow_redundant_wrapping: bool = false,
    prefer_rest_params: bool = true,
    prefer_object_spread: bool = true,
    prefer_spread: bool = true,
    prefer_template: bool = true,
    react_default_props_match_prop_types: bool = true,
    react_default_props_match_prop_types_allow_required_defaults: bool = false,
    react_display_name: bool = true,
    react_display_name_check_context_objects: bool = false,
    react_display_name_ignore_transpiler_name: bool = false,
    react_jsx_boolean_value: bool = true,
    react_jsx_boolean_value_style: ReactJsxBooleanValueStyle = .never,
    react_jsx_filename_extension: bool = true,
    react_jsx_filename_extension_extensions: ReactJsxFilenameExtensions = .{},
    react_jsx_no_duplicate_props: bool = true,
    react_jsx_no_duplicate_props_ignore_case: bool = true,
    react_jsx_no_comment_textnodes: bool = true,
    react_jsx_no_bind: bool = true,
    react_jsx_no_bind_allow_arrow_functions: bool = false,
    react_jsx_no_bind_allow_functions: bool = false,
    react_jsx_no_bind_allow_bind: bool = false,
    react_jsx_no_bind_ignore_refs: bool = false,
    react_jsx_no_bind_ignore_dom_components: bool = false,
    react_jsx_key: bool = true,
    react_jsx_key_check_key_must_before_spread: bool = false,
    react_jsx_key_check_fragment_shorthand: bool = false,
    react_button_has_type: bool = true,
    react_button_has_type_button: bool = true,
    react_button_has_type_submit: bool = true,
    react_button_has_type_reset: bool = true,
    react_require_render_return: bool = true,
    react_jsx_no_target_blank: bool = true,
    react_jsx_no_target_blank_allow_referrer: bool = false,
    react_jsx_no_target_blank_enforce_dynamic_links: bool = true,
    react_jsx_no_undef: bool = true,
    react_jsx_pascal_case: bool = true,
    react_jsx_pascal_case_allow_all_caps: bool = true,
    react_jsx_pascal_case_ignore: ReactJsxPascalCaseIgnoreNames = .{},
    react_jsx_uses_react: bool = true,
    react_jsx_uses_vars: bool = true,
    react_no_danger: bool = true,
    react_no_danger_with_children: bool = true,
    react_no_access_state_in_setstate: bool = true,
    react_no_deprecated: bool = true,
    react_forbid_prop_types: bool = true,
    react_forbid_prop_types_forbid_any: bool = true,
    react_forbid_prop_types_forbid_array: bool = true,
    react_forbid_prop_types_forbid_object: bool = true,
    react_no_array_index_key: bool = true,
    react_no_children_prop: bool = true,
    react_no_find_dom_node: bool = true,
    react_no_is_mounted: bool = true,
    react_no_multi_comp: bool = true,
    react_no_multi_comp_ignore_stateless: bool = true,
    react_no_redundant_should_component_update: bool = true,
    react_no_render_return_value: bool = true,
    react_no_will_update_set_state: bool = true,
    react_no_this_in_sfc: bool = true,
    react_no_typos: bool = true,
    react_no_unknown_property: bool = true,
    react_no_unknown_property_ignore: ReactNoUnknownPropertyIgnoreNames = .{},
    react_no_unknown_property_require_data_lowercase: bool = false,
    react_prop_types: bool = true,
    react_prop_types_skip_undeclared: bool = false,
    react_no_unused_prop_types: bool = true,
    react_no_unused_prop_types_skip_shape_props: bool = true,
    react_no_unused_state: bool = true,
    react_no_string_refs: bool = true,
    react_no_string_refs_no_template_literals: bool = false,
    react_no_unescaped_entities: bool = true,
    react_no_unescaped_entities_forbid_gt: bool = true,
    react_no_unescaped_entities_forbid_double_quote: bool = true,
    react_no_unescaped_entities_forbid_single_quote: bool = true,
    react_no_unescaped_entities_forbid_closing_brace: bool = true,
    react_prefer_es6_class: bool = true,
    react_prefer_es6_class_style: ReactPreferEs6ClassStyle = .always,
    react_self_closing_comp: bool = true,
    react_self_closing_comp_component: bool = true,
    react_self_closing_comp_html: bool = true,
    react_style_prop_object: bool = true,
    react_void_dom_elements_no_children: bool = true,
    react_hooks_rules_of_hooks: bool = true,
    radix: bool = true,
    radix_style: RadixStyle = .always,
    require_await: bool = true,
    require_atomic_updates: bool = true,
    require_atomic_updates_allow_properties: bool = false,
    require_yield: bool = true,
    spaced_comment: bool = true,
    spaced_comment_style: SpacedCommentStyle = .always,
    spaced_comment_markers: SpacedCommentMarkers = .{},
    spaced_comment_exceptions: SpacedCommentMarkers = .{},
    symbol_description: bool = true,
    typescript_eslint_adjacent_overload_signatures: bool = true,
    typescript_eslint_array_type: bool = true,
    typescript_eslint_array_type_style: TypescriptEslintArrayTypeStyle = .array_simple,
    typescript_eslint_class_literal_property_style: bool = true,
    typescript_eslint_class_literal_property_style_style: TypescriptEslintClassLiteralPropertyStyle = .fields,
    typescript_eslint_consistent_type_assertions: bool = true,
    typescript_eslint_consistent_type_definitions: bool = true,
    typescript_eslint_consistent_type_definitions_style: TypescriptEslintConsistentTypeDefinitionsStyle = .interface,
    typescript_eslint_no_array_constructor: bool = true,
    typescript_eslint_ban_types: bool = true,
    typescript_eslint_ban_types_config: TypescriptEslintBanTypesConfig = .{},
    typescript_eslint_ban_ts_comment: bool = true,
    typescript_eslint_ban_ts_comment_ts_expect_error: TypescriptEslintBanTsCommentMode = .allow_with_description,
    typescript_eslint_ban_ts_comment_ts_ignore: TypescriptEslintBanTsCommentMode = .allow_with_description,
    typescript_eslint_ban_ts_comment_ts_nocheck: TypescriptEslintBanTsCommentMode = .allow_with_description,
    typescript_eslint_ban_ts_comment_ts_check: TypescriptEslintBanTsCommentMode = .allow_with_description,
    typescript_eslint_ban_ts_comment_minimum_description_length: usize = 3,
    typescript_eslint_ban_tslint_comment: bool = true,
    typescript_eslint_explicit_member_accessibility: bool = true,
    typescript_eslint_explicit_member_accessibility_accessibility: TypescriptEslintExplicitMemberAccessibility = .no_public,
    typescript_eslint_consistent_type_assertions_assertion_style: TypescriptEslintConsistentTypeAssertionsStyle = .as,
    typescript_eslint_consistent_type_assertions_object_literal_type_assertions: TypescriptEslintLiteralTypeAssertions = .never,
    typescript_eslint_consistent_type_assertions_array_literal_type_assertions: TypescriptEslintLiteralTypeAssertions = .allow,
    typescript_eslint_member_ordering: bool = true,
    typescript_eslint_method_signature_style: bool = true,
    typescript_eslint_method_signature_style_style: TypescriptEslintMethodSignatureStyle = .property,
    typescript_eslint_no_confusing_non_null_assertion: bool = true,
    typescript_eslint_no_empty_function: bool = true,
    typescript_eslint_no_empty_function_allow: NoEmptyFunctionAllow = .{},
    typescript_eslint_no_empty_interface: bool = true,
    typescript_eslint_no_empty_interface_allow_single_extends: bool = false,
    typescript_eslint_no_extra_semi: bool = true,
    typescript_eslint_no_extra_non_null_assertion: bool = true,
    typescript_eslint_no_duplicate_enum_values: bool = true,
    typescript_eslint_no_inferrable_types: bool = true,
    typescript_eslint_no_inferrable_types_ignore_parameters: bool = false,
    typescript_eslint_no_inferrable_types_ignore_properties: bool = false,
    typescript_eslint_no_invalid_void_type: bool = true,
    typescript_eslint_no_invalid_void_type_allow_as_this_parameter: bool = false,
    typescript_eslint_no_invalid_void_type_allow_in_generic_type_arguments: bool = true,
    typescript_eslint_no_loss_of_precision: bool = true,
    typescript_eslint_no_loop_func: bool = true,
    typescript_eslint_no_misused_new: bool = true,
    typescript_eslint_no_non_null_asserted_optional_chain: bool = true,
    typescript_eslint_no_namespace: bool = true,
    typescript_eslint_no_namespace_allow_declarations: bool = true,
    typescript_eslint_no_namespace_allow_definition_files: bool = true,
    typescript_eslint_no_redeclare: bool = true,
    typescript_eslint_no_redeclare_builtin_globals: bool = false,
    typescript_eslint_no_redeclare_ignore_declaration_merge: bool = true,
    typescript_eslint_no_require_imports: bool = true,
    typescript_eslint_no_shadow: bool = true,
    typescript_eslint_no_shadow_allow: NoShadowAllowNames = .{},
    typescript_eslint_no_shadow_builtin_globals: bool = false,
    typescript_eslint_no_shadow_hoist: NoShadowHoist = .functions_and_types,
    typescript_eslint_no_shadow_ignore_on_initialization: bool = false,
    typescript_eslint_no_shadow_ignore_type_value_shadow: bool = false,
    typescript_eslint_no_shadow_ignore_function_type_parameter_name_value_shadow: bool = true,
    typescript_eslint_no_this_alias: bool = true,
    typescript_eslint_no_this_alias_allowed_names: NoThisAliasAllowedNames = .{},
    typescript_eslint_no_unsafe_declaration_merging: bool = true,
    typescript_eslint_triple_slash_reference: bool = true,
    typescript_eslint_triple_slash_reference_path: TypescriptEslintTripleSlashReferenceMode = .never,
    typescript_eslint_triple_slash_reference_types: TypescriptEslintTripleSlashReferenceMode = .always,
    typescript_eslint_triple_slash_reference_lib: TypescriptEslintTripleSlashReferenceMode = .always,
    typescript_eslint_typedef: bool = true,
    typescript_eslint_typedef_property_declaration: bool = true,
    typescript_eslint_typedef_member_variable_declaration: bool = false,
    typescript_eslint_typedef_parameter: bool = false,
    typescript_eslint_typedef_arrow_parameter: bool = false,
    typescript_eslint_typedef_array_destructuring: bool = false,
    typescript_eslint_typedef_object_destructuring: bool = false,
    typescript_eslint_typedef_variable_declaration: bool = false,
    typescript_eslint_typedef_variable_declaration_ignore_function: bool = false,
    typescript_eslint_unified_signatures: bool = true,
    typescript_eslint_no_unnecessary_parameter_property_assignment: bool = true,
    typescript_eslint_no_unnecessary_type_constraint: bool = true,
    typescript_eslint_no_useless_constructor: bool = true,
    typescript_eslint_no_useless_empty_export: bool = true,
    typescript_eslint_no_unused_vars: bool = true,
    typescript_eslint_no_unused_vars_vars: NoUnusedVarsVars = .all,
    typescript_eslint_no_unused_vars_args: NoUnusedVarsArgs = .after_used,
    typescript_eslint_no_unused_vars_caught_errors: NoUnusedVarsCaughtErrors = .all,
    typescript_eslint_no_unused_vars_ignore_rest_siblings: bool = true,
    typescript_eslint_no_unused_vars_ignore_class_with_static_init_block: bool = false,
    typescript_eslint_no_unused_vars_ignore_using_declarations: bool = false,
    typescript_eslint_no_unused_vars_args_ignore_pattern: NoUnusedVarsIgnorePattern = .{},
    typescript_eslint_no_unused_vars_caught_errors_ignore_pattern: NoUnusedVarsIgnorePattern = .{},
    typescript_eslint_no_unused_vars_destructured_array_ignore_pattern: NoUnusedVarsIgnorePattern = .{},
    typescript_eslint_no_unused_vars_report_used_ignore_pattern: bool = false,
    typescript_eslint_no_unused_vars_vars_ignore_pattern: NoUnusedVarsIgnorePattern = .{},
    typescript_eslint_no_use_before_define: bool = true,
    typescript_eslint_no_use_before_define_check_functions: NoUseBeforeDefineCheck = .no,
    typescript_eslint_no_use_before_define_check_classes: NoUseBeforeDefineCheck = .yes,
    typescript_eslint_no_use_before_define_check_variables: NoUseBeforeDefineCheck = .yes,
    typescript_eslint_no_use_before_define_check_typedefs: NoUseBeforeDefineCheck = .yes,
    typescript_eslint_no_use_before_define_check_enums: NoUseBeforeDefineCheck = .yes,
    typescript_eslint_no_use_before_define_allow_named_exports: bool = false,
    typescript_eslint_no_use_before_define_ignore_type_references: bool = true,
    typescript_eslint_no_var_requires: bool = true,
    typescript_eslint_no_wrapper_object_types: bool = true,
    typescript_eslint_prefer_as_const: bool = true,
    typescript_eslint_prefer_namespace_keyword: bool = true,
    typescript_eslint_restrict_plus_operands: bool = true,
    typescript_eslint_restrict_plus_operands_allow_number_and_string: bool = false,
    parser_semantic_errors: bool = true,
    valid_typeof: bool = true,
    valid_typeof_require_string_literals: bool = false,
    vars_on_top: bool = true,
    wrap_iife: bool = true,
    wrap_iife_style: WrapIifeStyle = .outside,
    yoda: bool = true,
    yoda_style: YodaStyle = .never,
    yoda_only_equality: bool = false,
    yoda_except_range: bool = false,

    pub fn allDisabled() Options {
        var options = Options{};
        inline for (@typeInfo(Options).@"struct".fields) |field| {
            if (field.type == bool) {
                @field(options, field.name) = false;
            }
        }
        return options;
    }

    pub fn setByCliName(self: *Options, cli_name: []const u8, value: bool) bool {
        @setEvalBranchQuota(10000);

        if (std.mem.eql(u8, cli_name, "semantic-errors")) {
            self.parser_semantic_errors = value;
            return true;
        }

        if (std.mem.eql(u8, cli_name, "prettier/prettier")) {
            return true;
        }

        if (std.mem.startsWith(u8, cli_name, "@typescript-eslint/")) {
            const typescript_rule_name = cli_name["@typescript-eslint/".len..];
            inline for (@typeInfo(Options).@"struct".fields) |field| {
                if (field.type == bool) {
                    if (comptime fieldNameStartsWith(field.name, "typescript_eslint_")) {
                        if (cliNameMatchesFieldName(field.name["typescript_eslint_".len..], typescript_rule_name)) {
                            @field(self, field.name) = value;
                            return true;
                        }
                    }
                }
            }
            return false;
        }

        if (std.mem.startsWith(u8, cli_name, "import/")) {
            return self.setByPrefixedRuleName("import_", cli_name["import/".len..], value);
        }

        if (std.mem.startsWith(u8, cli_name, "eslint-comments/")) {
            return self.setByPrefixedRuleName("eslint_comments_", cli_name["eslint-comments/".len..], value);
        }

        if (std.mem.startsWith(u8, cli_name, "@alipay/ant/")) {
            return self.setByPrefixedRuleName("alipay_ant_", cli_name["@alipay/ant/".len..], value);
        }

        if (std.mem.startsWith(u8, cli_name, "@alipay/spmLint/")) {
            return self.setByPrefixedRuleName("alipay_spmlint_", cli_name["@alipay/spmLint/".len..], value);
        }

        if (std.mem.startsWith(u8, cli_name, "jsx-a11y/")) {
            return self.setByPrefixedRuleName("jsx_a11y_", cli_name["jsx-a11y/".len..], value);
        }

        if (std.mem.startsWith(u8, cli_name, "react/")) {
            return self.setByPrefixedRuleName("react_", cli_name["react/".len..], value);
        }

        if (std.mem.startsWith(u8, cli_name, "react-hooks/")) {
            return self.setByPrefixedRuleName("react_hooks_", cli_name["react-hooks/".len..], value);
        }

        inline for (@typeInfo(Options).@"struct".fields) |field| {
            if (field.type == bool and cliNameMatchesFieldName(field.name, cli_name)) {
                @field(self, field.name) = value;
                return true;
            }
        }
        return false;
    }

    pub fn setByRuleConfigValue(self: *Options, cli_name: []const u8, value: std.json.Value) RuleConfigError!void {
        const enabled = try ruleConfigValueToBool(value);
        if (!self.setByCliName(cli_name, enabled)) return error.UnknownRule;
        if (std.mem.eql(u8, cli_name, "@alipay/ant/no-deprecated-dependence")) {
            self.alipay_ant_no_deprecated_dependence_profile = deprecatedDependenceProfileFromConfig(value);
        }
        if (std.mem.eql(u8, cli_name, "accessor-pairs")) {
            self.accessor_pairs_get_without_set = try accessorPairsGetWithoutSetFromConfig(value);
            self.accessor_pairs_set_without_get = try accessorPairsSetWithoutGetFromConfig(value);
            self.accessor_pairs_enforce_for_class_members = try accessorPairsEnforceForClassMembersFromConfig(value);
        }
        if (std.mem.eql(u8, cli_name, "array-callback-return")) {
            self.array_callback_return_allow_implicit = try arrayCallbackReturnAllowImplicitFromConfig(value);
            self.array_callback_return_check_for_each = try arrayCallbackReturnCheckForEachFromConfig(value);
            self.array_callback_return_allow_void = try arrayCallbackReturnAllowVoidFromConfig(value);
        }
        if (std.mem.eql(u8, cli_name, "capitalized-comments")) {
            self.capitalized_comments_mode = try capitalizedCommentsModeFromConfig(value);
            self.capitalized_comments_ignore_inline_comments = try capitalizedCommentsIgnoreInlineCommentsFromConfig(value);
            self.capitalized_comments_ignore_consecutive_comments = try capitalizedCommentsIgnoreConsecutiveCommentsFromConfig(value);
        }
        if (std.mem.eql(u8, cli_name, "consistent-return")) {
            self.consistent_return_treat_undefined_as_unspecified = try consistentReturnTreatUndefinedAsUnspecifiedFromConfig(value);
        }
        if (std.mem.eql(u8, cli_name, "curly")) {
            self.curly_style = try curlyStyleFromConfig(value);
        }
        if (std.mem.eql(u8, cli_name, "default-case")) {
            self.default_case_comment_pattern = try defaultCaseCommentPatternFromConfig(value);
        }
        if (enabled and (std.mem.eql(u8, cli_name, "dot-notation") or std.mem.eql(u8, cli_name, "@typescript-eslint/dot-notation"))) {
            self.dot_notation_allow_keywords = try dotNotationAllowKeywordsFromConfig(value);
            self.dot_notation_allow_pattern = try dotNotationAllowPatternFromConfig(value);
        }
        if (std.mem.eql(u8, cli_name, "eol-last")) {
            self.eol_last_style = try eolLastStyleFromConfig(value);
        }
        if (std.mem.eql(u8, cli_name, "eslint-comments/no-restricted-disable")) {
            self.eslint_comments_no_restricted_disable_no_nested_ternary = noRestrictedDisableRestrictsNoNestedTernary(value);
        }
        if (std.mem.eql(u8, cli_name, "func-name-matching")) {
            self.func_name_matching_style = try funcNameMatchingStyleFromConfig(value);
        }
        if (std.mem.eql(u8, cli_name, "func-names")) {
            self.func_names_style = try funcNamesStyleFromConfig(value);
            const generator_style = try funcNamesGeneratorStyleFromConfig(value);
            self.func_names_has_generator_style = generator_style != null;
            self.func_names_generator_style = generator_style orelse self.func_names_style;
        }
        if (std.mem.eql(u8, cli_name, "grouped-accessor-pairs")) {
            self.grouped_accessor_pairs_style = try groupedAccessorPairsStyleFromConfig(value);
        }
        if (std.mem.eql(u8, cli_name, "eqeqeq")) {
            self.eqeqeq_style = try eqeqeqStyleFromConfig(value);
        }
        if (std.mem.eql(u8, cli_name, "linebreak-style")) {
            self.linebreak_style_style = try linebreakStyleFromConfig(value);
        }
        if (std.mem.eql(u8, cli_name, "use-isnan")) {
            self.use_isnan_enforce_for_index_of = try useIsnanBoolOptionFromConfig(value, "enforceForIndexOf", false);
            self.use_isnan_enforce_for_switch_case = try useIsnanBoolOptionFromConfig(value, "enforceForSwitchCase", true);
        }
        if (std.mem.eql(u8, cli_name, "logical-assignment-operators")) {
            self.logical_assignment_operators_style = try logicalAssignmentOperatorsStyleFromConfig(value);
            self.logical_assignment_operators_enforce_for_if_statements = try logicalAssignmentOperatorsEnforceForIfStatementsFromConfig(value);
        }
        if (std.mem.eql(u8, cli_name, "import/newline-after-import")) {
            self.import_newline_after_import_count = try importNewlineAfterImportCountFromConfig(value);
            self.import_newline_after_import_exact_count = try importNewlineAfterImportExactCountFromConfig(value);
        }
        if (std.mem.eql(u8, cli_name, "new-cap")) {
            self.new_cap_new_is_cap = try newCapBoolOptionFromConfig(value, "newIsCap", true);
            self.new_cap_cap_is_new = try newCapBoolOptionFromConfig(value, "capIsNew", true);
            self.new_cap_properties = try newCapBoolOptionFromConfig(value, "properties", true);
            self.new_cap_new_is_cap_exceptions = try newCapExceptionNamesFromConfig(value, "newIsCapExceptions");
            self.new_cap_cap_is_new_exceptions = try newCapExceptionNamesFromConfig(value, "capIsNewExceptions");
            self.new_cap_new_is_cap_exception_pattern = try newCapExceptionPatternFromConfig(value, "newIsCapExceptionPattern");
            self.new_cap_cap_is_new_exception_pattern = try newCapExceptionPatternFromConfig(value, "capIsNewExceptionPattern");
        }
        if (std.mem.eql(u8, cli_name, "no-bitwise")) {
            self.no_bitwise_allow_bitwise_and = try noBitwiseAllowFromConfig(value, "&");
            self.no_bitwise_allow_bitwise_or = try noBitwiseAllowFromConfig(value, "|");
            self.no_bitwise_allow_bitwise_xor = try noBitwiseAllowFromConfig(value, "^");
            self.no_bitwise_allow_bitwise_not = try noBitwiseAllowFromConfig(value, "~");
            self.no_bitwise_allow_left_shift = try noBitwiseAllowFromConfig(value, "<<");
            self.no_bitwise_allow_right_shift = try noBitwiseAllowFromConfig(value, ">>");
            self.no_bitwise_allow_unsigned_right_shift = try noBitwiseAllowFromConfig(value, ">>>");
            self.no_bitwise_int32_hint = try noBitwiseInt32HintFromConfig(value);
        }
        if (std.mem.eql(u8, cli_name, "no-console")) {
            self.no_console_allow = try noConsoleAllowFromConfig(value);
        }
        if (std.mem.eql(u8, cli_name, "no-duplicate-imports")) {
            self.no_duplicate_imports_allow_separate_type_imports = try noDuplicateImportsBoolOptionFromConfig(value, "allowSeparateTypeImports", false);
        }
        if (std.mem.eql(u8, cli_name, "no-cond-assign")) {
            self.no_cond_assign_style = try noCondAssignStyleFromConfig(value);
        }
        if (std.mem.eql(u8, cli_name, "no-constant-condition")) {
            self.no_constant_condition_check_loops = try noConstantConditionCheckLoopsFromConfig(value);
        }
        if (std.mem.eql(u8, cli_name, "no-confusing-arrow")) {
            self.no_confusing_arrow_allow_parens = try noConfusingArrowAllowParensFromConfig(value);
        }
        if (std.mem.eql(u8, cli_name, "no-empty")) {
            self.no_empty_allow_empty_catch = try noEmptyAllowEmptyCatchFromConfig(value);
        }
        if (std.mem.eql(u8, cli_name, "no-empty-function")) {
            self.no_empty_function_allow = try noEmptyFunctionAllowFromConfig(value);
        }
        if (std.mem.eql(u8, cli_name, "no-eval")) {
            self.no_eval_allow_indirect = try noEvalAllowIndirectFromConfig(value);
        }
        if (std.mem.eql(u8, cli_name, "no-extend-native")) {
            self.no_extend_native_exceptions = try noExtendNativeExceptionsFromConfig(value);
        }
        if (std.mem.eql(u8, cli_name, "no-global-assign")) {
            self.no_global_assign_exceptions = try noGlobalAssignExceptionsFromConfig(value);
        }
        if (std.mem.eql(u8, cli_name, "@typescript-eslint/no-empty-function")) {
            self.typescript_eslint_no_empty_function_allow = try noEmptyFunctionAllowFromConfig(value);
        }
        if (std.mem.eql(u8, cli_name, "no-empty-pattern")) {
            self.no_empty_pattern_allow_object_patterns_as_parameters = try noEmptyPatternAllowObjectPatternsAsParametersFromConfig(value);
        }
        if (std.mem.eql(u8, cli_name, "no-else-return")) {
            self.no_else_return_allow_else_if = try noElseReturnAllowElseIfFromConfig(value);
        }
        if (std.mem.eql(u8, cli_name, "no-extra-boolean-cast")) {
            self.no_extra_boolean_cast_enforce_for_inner_expressions = try noExtraBooleanCastEnforceForInnerExpressionsFromConfig(value);
        }
        if (std.mem.eql(u8, cli_name, "no-fallthrough")) {
            self.no_fallthrough_allow_empty_case = try noFallthroughAllowEmptyCaseFromConfig(value);
            self.no_fallthrough_comment_pattern = try noFallthroughCommentPatternFromConfig(value);
            self.no_fallthrough_report_unused_fallthrough_comment = try noFallthroughReportUnusedFallthroughCommentFromConfig(value);
        }
        if (std.mem.eql(u8, cli_name, "no-implicit-coercion")) {
            self.no_implicit_coercion_boolean = try noImplicitCoercionBooleanFromConfig(value);
            self.no_implicit_coercion_number = try noImplicitCoercionNumberFromConfig(value);
            self.no_implicit_coercion_string = try noImplicitCoercionStringFromConfig(value);
            self.no_implicit_coercion_allow_double_negation = try noImplicitCoercionAllowFromConfig(value, "!!");
            self.no_implicit_coercion_allow_bitwise_not = try noImplicitCoercionAllowFromConfig(value, "~");
            self.no_implicit_coercion_allow_plus = try noImplicitCoercionAllowFromConfig(value, "+");
            self.no_implicit_coercion_allow_multiply = try noImplicitCoercionAllowFromConfig(value, "*");
            self.no_implicit_coercion_allow_subtract = try noImplicitCoercionAllowFromConfig(value, "-");
            self.no_implicit_coercion_allow_double_negative = try noImplicitCoercionAllowFromConfig(value, "- -");
            self.no_implicit_coercion_disallow_template_shorthand = try noImplicitCoercionDisallowTemplateShorthandFromConfig(value);
        }
        if (std.mem.eql(u8, cli_name, "no-inner-declarations")) {
            self.no_inner_declarations_mode = try noInnerDeclarationsModeFromConfig(value);
        }
        if (std.mem.eql(u8, cli_name, "no-invalid-regexp")) {
            self.no_invalid_regexp_allow_constructor_flags = try noInvalidRegexpAllowConstructorFlagsFromConfig(value);
        }
        if (std.mem.eql(u8, cli_name, "no-irregular-whitespace")) {
            self.no_irregular_whitespace_skip_strings = try noIrregularWhitespaceBoolOptionFromConfig(value, "skipStrings", true);
            self.no_irregular_whitespace_skip_comments = try noIrregularWhitespaceBoolOptionFromConfig(value, "skipComments", false);
            self.no_irregular_whitespace_skip_reg_exps = try noIrregularWhitespaceBoolOptionFromConfig(value, "skipRegExps", false);
            self.no_irregular_whitespace_skip_templates = try noIrregularWhitespaceBoolOptionFromConfig(value, "skipTemplates", false);
            self.no_irregular_whitespace_skip_jsx_text = try noIrregularWhitespaceBoolOptionFromConfig(value, "skipJSXText", false);
        }
        if (std.mem.eql(u8, cli_name, "no-inline-comments")) {
            self.no_inline_comments_ignore_pattern = try noInlineCommentsIgnorePatternFromConfig(value);
        }
        if (std.mem.eql(u8, cli_name, "no-labels")) {
            self.no_labels_allow_loop = try noLabelsAllowLoopFromConfig(value);
            self.no_labels_allow_switch = try noLabelsAllowSwitchFromConfig(value);
        }
        if (std.mem.eql(u8, cli_name, "no-mixed-spaces-and-tabs")) {
            self.no_mixed_spaces_and_tabs_smart_tabs = try noMixedSpacesAndTabsSmartTabsFromConfig(value);
        }
        if (std.mem.eql(u8, cli_name, "no-multi-assign")) {
            self.no_multi_assign_ignore_non_declaration = try noMultiAssignBoolOptionFromConfig(value, "ignoreNonDeclaration", false);
        }
        if (std.mem.eql(u8, cli_name, "no-multi-spaces")) {
            self.no_multi_spaces_ignore_eol_comments = try noMultiSpacesIgnoreEOLCommentsFromConfig(value);
            self.no_multi_spaces_exceptions = try noMultiSpacesExceptionsFromConfig(value);
        }
        if (std.mem.eql(u8, cli_name, "no-multiple-empty-lines")) {
            self.no_multiple_empty_lines_max = try noMultipleEmptyLinesMaxFromConfig(value);
            self.no_multiple_empty_lines_max_bof = try noMultipleEmptyLinesMaxBofFromConfig(value);
            self.no_multiple_empty_lines_max_eof = try noMultipleEmptyLinesMaxEofFromConfig(value);
        }
        if (std.mem.eql(u8, cli_name, "no-param-reassign")) {
            self.no_param_reassign_props = try noParamReassignPropsFromConfig(value);
            self.no_param_reassign_ignore_property_modifications_for = try noParamReassignIgnoredNamesFromConfig(value);
            self.no_param_reassign_ignore_property_modifications_for_regex = try noParamReassignIgnoredNamePatternsFromConfig(value);
        }
        if (std.mem.eql(u8, cli_name, "no-redeclare")) {
            self.no_redeclare_builtin_globals = try noRedeclareBuiltinGlobalsFromConfig(value);
        }
        if (std.mem.eql(u8, cli_name, "no-self-assign")) {
            self.no_self_assign_props = try noSelfAssignPropsFromConfig(value);
        }
        if (std.mem.eql(u8, cli_name, "no-trailing-spaces")) {
            self.no_trailing_spaces_skip_blank_lines = try noTrailingSpacesBoolOptionFromConfig(value, "skipBlankLines");
            self.no_trailing_spaces_ignore_comments = try noTrailingSpacesBoolOptionFromConfig(value, "ignoreComments");
        }
        if (std.mem.eql(u8, cli_name, "no-unsafe-negation")) {
            self.no_unsafe_negation_enforce_for_ordering_relations = try noUnsafeNegationBoolOptionFromConfig(value, "enforceForOrderingRelations", false);
        }
        if (std.mem.eql(u8, cli_name, "no-useless-rename")) {
            self.no_useless_rename_ignore_destructuring = try noUselessRenameBoolOptionFromConfig(value, "ignoreDestructuring");
            self.no_useless_rename_ignore_import = try noUselessRenameBoolOptionFromConfig(value, "ignoreImport");
            self.no_useless_rename_ignore_export = try noUselessRenameBoolOptionFromConfig(value, "ignoreExport");
        }
        if (std.mem.eql(u8, cli_name, "no-useless-escape")) {
            self.no_useless_escape_allow_regex_characters = try noUselessEscapeAllowRegexCharactersFromConfig(value);
        }
        if (std.mem.eql(u8, cli_name, "unicode-bom")) {
            self.unicode_bom_style = try unicodeBomStyleFromConfig(value);
        }
        if (std.mem.eql(u8, cli_name, "no-shadow")) {
            self.no_shadow_allow = try noShadowAllowFromConfig(value);
            self.no_shadow_builtin_globals = try noShadowBuiltinGlobalsFromConfig(value);
            self.no_shadow_hoist = try noShadowHoistFromConfig(value, .functions);
            self.no_shadow_ignore_on_initialization = try noShadowBoolOptionFromConfig(value, "ignoreOnInitialization", false);
        }
        if (std.mem.eql(u8, cli_name, "no-underscore-dangle")) {
            self.no_underscore_dangle_allow_after_this = try noUnderscoreDangleBoolOptionFromConfig(value, "allowAfterThis", false);
            self.no_underscore_dangle_allow_after_super = try noUnderscoreDangleBoolOptionFromConfig(value, "allowAfterSuper", false);
            self.no_underscore_dangle_allow_after_this_constructor = try noUnderscoreDangleBoolOptionFromConfig(value, "allowAfterThisConstructor", false);
            self.no_underscore_dangle_allow_function_params = if (try noUnderscoreDangleBoolOptionFromConfig(value, "allowFunctionParams", true)) .yes else .no;
            self.no_underscore_dangle_allow_in_array_destructuring = if (try noUnderscoreDangleBoolOptionFromConfig(value, "allowInArrayDestructuring", true)) .yes else .no;
            self.no_underscore_dangle_allow_in_object_destructuring = if (try noUnderscoreDangleBoolOptionFromConfig(value, "allowInObjectDestructuring", true)) .yes else .no;
            self.no_underscore_dangle_enforce_in_method_names = try noUnderscoreDangleBoolOptionFromConfig(value, "enforceInMethodNames", false);
            self.no_underscore_dangle_enforce_in_class_fields = try noUnderscoreDangleBoolOptionFromConfig(value, "enforceInClassFields", false);
            self.no_underscore_dangle_allow = try noUnderscoreDangleAllowFromConfig(value);
        }
        if (std.mem.eql(u8, cli_name, "no-plusplus")) {
            self.no_plusplus_allow_for_loop_afterthoughts = try noPlusplusAllowForLoopAfterthoughtsFromConfig(value);
        }
        if (std.mem.eql(u8, cli_name, "no-promise-executor-return")) {
            self.no_promise_executor_return_allow_void = try noPromiseExecutorReturnAllowVoidFromConfig(value);
        }
        if (std.mem.eql(u8, cli_name, "prefer-const")) {
            self.prefer_const_destructuring = try preferConstDestructuringFromConfig(value);
            self.prefer_const_ignore_read_before_assign = try preferConstBoolOptionFromConfig(value, "ignoreReadBeforeAssign", true);
        }
        if (std.mem.eql(u8, cli_name, "prefer-destructuring")) {
            self.prefer_destructuring_variable_declarator_array = try preferDestructuringOptionFromConfig(value, "VariableDeclarator", "array", true);
            self.prefer_destructuring_variable_declarator_object = try preferDestructuringOptionFromConfig(value, "VariableDeclarator", "object", true);
            self.prefer_destructuring_assignment_expression_array = try preferDestructuringOptionFromConfig(value, "AssignmentExpression", "array", true);
            self.prefer_destructuring_assignment_expression_object = try preferDestructuringOptionFromConfig(value, "AssignmentExpression", "object", true);
            self.prefer_destructuring_enforce_for_renamed_properties = try preferDestructuringEnforceForRenamedPropertiesFromConfig(value);
        }
        if (std.mem.eql(u8, cli_name, "prefer-promise-reject-errors")) {
            self.prefer_promise_reject_errors_allow_empty_reject = try preferPromiseRejectErrorsAllowEmptyRejectFromConfig(value);
        }
        if (std.mem.eql(u8, cli_name, "prefer-regex-literals")) {
            self.prefer_regex_literals_disallow_redundant_wrapping = try preferRegexLiteralsDisallowRedundantWrappingFromConfig(value);
        }
        if (std.mem.eql(u8, cli_name, "radix")) {
            self.radix_style = try radixStyleFromConfig(value);
        }
        if (std.mem.eql(u8, cli_name, "require-atomic-updates")) {
            self.require_atomic_updates_allow_properties = try requireAtomicUpdatesBoolOptionFromConfig(value, "allowProperties", false);
        }
        if (std.mem.eql(u8, cli_name, "no-return-assign")) {
            self.no_return_assign_style = try noReturnAssignStyleFromConfig(value);
        }
        if (std.mem.eql(u8, cli_name, "no-sequences")) {
            self.no_sequences_allow_in_parentheses = try noSequencesAllowInParenthesesFromConfig(value);
        }
        if (std.mem.eql(u8, cli_name, "no-useless-computed-key")) {
            self.no_useless_computed_key_enforce_for_class_members = try noUselessComputedKeyEnforceForClassMembersFromConfig(value);
        }
        if (std.mem.eql(u8, cli_name, "no-unused-expressions")) {
            self.no_unused_expressions_allow_short_circuit = try noUnusedExpressionsAllowShortCircuitFromConfig(value);
            self.no_unused_expressions_allow_ternary = try noUnusedExpressionsAllowTernaryFromConfig(value);
            self.no_unused_expressions_allow_tagged_templates = try noUnusedExpressionsAllowTaggedTemplatesFromConfig(value);
        }
        if (std.mem.eql(u8, cli_name, "@typescript-eslint/no-unused-expressions")) {
            self.typescript_eslint_no_unused_expressions_allow_short_circuit = try noUnusedExpressionsAllowShortCircuitFromConfig(value);
            self.typescript_eslint_no_unused_expressions_allow_ternary = try noUnusedExpressionsAllowTernaryFromConfig(value);
            self.typescript_eslint_no_unused_expressions_allow_tagged_templates = try noUnusedExpressionsAllowTaggedTemplatesFromConfig(value);
        }
        if (std.mem.eql(u8, cli_name, "no-unused-vars")) {
            self.no_unused_vars_vars = try noUnusedVarsVarsFromConfig(value, .all);
            self.no_unused_vars_args = try noUnusedVarsArgsFromConfig(value, .none);
            self.no_unused_vars_caught_errors = try noUnusedVarsCaughtErrorsFromConfig(value, .all);
            self.no_unused_vars_ignore_rest_siblings = try noUnusedVarsIgnoreRestSiblingsFromConfig(value, false);
            self.no_unused_vars_ignore_class_with_static_init_block = try noUnusedVarsBoolOptionFromConfig(value, "ignoreClassWithStaticInitBlock", false);
            self.no_unused_vars_ignore_using_declarations = try noUnusedVarsBoolOptionFromConfig(value, "ignoreUsingDeclarations", false);
            self.no_unused_vars_args_ignore_pattern = try noUnusedVarsIgnorePatternFromConfig(value, "argsIgnorePattern");
            self.no_unused_vars_caught_errors_ignore_pattern = try noUnusedVarsIgnorePatternFromConfig(value, "caughtErrorsIgnorePattern");
            self.no_unused_vars_destructured_array_ignore_pattern = try noUnusedVarsIgnorePatternFromConfig(value, "destructuredArrayIgnorePattern");
            self.no_unused_vars_report_used_ignore_pattern = try noUnusedVarsReportUsedIgnorePatternFromConfig(value, false);
            self.no_unused_vars_vars_ignore_pattern = try noUnusedVarsIgnorePatternFromConfig(value, "varsIgnorePattern");
        }
        if (std.mem.eql(u8, cli_name, "no-use-before-define")) {
            self.no_use_before_define_check_functions = try noUseBeforeDefineCheckFromConfig(value, "functions", true);
            self.no_use_before_define_check_classes = try noUseBeforeDefineCheckFromConfig(value, "classes", true);
            self.no_use_before_define_check_variables = try noUseBeforeDefineCheckFromConfig(value, "variables", true);
            self.no_use_before_define_allow_named_exports = try noUseBeforeDefineAllowNamedExportsFromConfig(value);
        }
        if (std.mem.eql(u8, cli_name, "object-shorthand")) {
            self.object_shorthand_style = try objectShorthandStyleFromConfig(value);
            self.object_shorthand_avoid_quotes = try objectShorthandAvoidQuotesFromConfig(value);
            self.object_shorthand_ignore_constructors = try objectShorthandIgnoreConstructorsFromConfig(value);
            self.object_shorthand_avoid_explicit_return_arrows = try objectShorthandAvoidExplicitReturnArrowsFromConfig(value);
        }
        if (std.mem.eql(u8, cli_name, "one-var")) {
            const config = try oneVarNeverConfigFromConfig(value);
            self.one_var_check_var = config.@"var";
            self.one_var_check_let = config.let;
            self.one_var_check_const = config.@"const";
        }
        if (std.mem.eql(u8, cli_name, "operator-assignment")) {
            self.operator_assignment_style = try operatorAssignmentStyleFromConfig(value);
        }
        if (std.mem.eql(u8, cli_name, "react/default-props-match-prop-types")) {
            self.react_default_props_match_prop_types_allow_required_defaults = try reactDefaultPropsMatchPropTypesAllowRequiredDefaultsFromConfig(value);
        }
        if (std.mem.eql(u8, cli_name, "react/display-name")) {
            self.react_display_name_check_context_objects = try reactDisplayNameBoolOptionFromConfig(value, "checkContextObjects", false);
            self.react_display_name_ignore_transpiler_name = try reactDisplayNameBoolOptionFromConfig(value, "ignoreTranspilerName", false);
        }
        if (std.mem.eql(u8, cli_name, "react/button-has-type")) {
            self.react_button_has_type_button = try reactButtonHasTypeBoolOptionFromConfig(value, "button", true);
            self.react_button_has_type_submit = try reactButtonHasTypeBoolOptionFromConfig(value, "submit", true);
            self.react_button_has_type_reset = try reactButtonHasTypeBoolOptionFromConfig(value, "reset", true);
        }
        if (std.mem.eql(u8, cli_name, "react/forbid-prop-types")) {
            const forbid = try reactForbidPropTypesForbidFromConfig(value);
            self.react_forbid_prop_types_forbid_any = forbid.any;
            self.react_forbid_prop_types_forbid_array = forbid.array;
            self.react_forbid_prop_types_forbid_object = forbid.object;
        }
        if (std.mem.eql(u8, cli_name, "react/jsx-filename-extension")) {
            self.react_jsx_filename_extension_extensions = try reactJsxFilenameExtensionsFromConfig(value);
        }
        if (std.mem.eql(u8, cli_name, "react/jsx-boolean-value")) {
            self.react_jsx_boolean_value_style = try reactJsxBooleanValueStyleFromConfig(value);
        }
        if (std.mem.eql(u8, cli_name, "react/jsx-no-bind")) {
            self.react_jsx_no_bind_allow_arrow_functions = try reactJsxNoBindBoolOptionFromConfig(value, "allowArrowFunctions", false);
            self.react_jsx_no_bind_allow_functions = try reactJsxNoBindBoolOptionFromConfig(value, "allowFunctions", false);
            self.react_jsx_no_bind_allow_bind = try reactJsxNoBindBoolOptionFromConfig(value, "allowBind", false);
            self.react_jsx_no_bind_ignore_refs = try reactJsxNoBindBoolOptionFromConfig(value, "ignoreRefs", false);
            self.react_jsx_no_bind_ignore_dom_components = try reactJsxNoBindBoolOptionFromConfig(value, "ignoreDOMComponents", false);
        }
        if (std.mem.eql(u8, cli_name, "react/jsx-no-duplicate-props")) {
            self.react_jsx_no_duplicate_props_ignore_case = try reactJsxNoDuplicatePropsIgnoreCaseFromConfig(value);
        }
        if (std.mem.eql(u8, cli_name, "react/jsx-key")) {
            self.react_jsx_key_check_key_must_before_spread = try reactJsxKeyCheckKeyMustBeforeSpreadFromConfig(value);
            self.react_jsx_key_check_fragment_shorthand = try reactJsxKeyCheckFragmentShorthandFromConfig(value);
        }
        if (std.mem.eql(u8, cli_name, "react/jsx-no-target-blank")) {
            self.react_jsx_no_target_blank_allow_referrer = try reactJsxNoTargetBlankAllowReferrerFromConfig(value);
            self.react_jsx_no_target_blank_enforce_dynamic_links = try reactJsxNoTargetBlankEnforceDynamicLinksFromConfig(value);
        }
        if (std.mem.eql(u8, cli_name, "react/jsx-pascal-case")) {
            self.react_jsx_pascal_case_allow_all_caps = try reactJsxPascalCaseAllowAllCapsFromConfig(value);
            self.react_jsx_pascal_case_ignore = try reactJsxPascalCaseIgnoreFromConfig(value);
        }
        if (std.mem.eql(u8, cli_name, "react/prop-types")) {
            self.react_prop_types_skip_undeclared = try reactPropTypesSkipUndeclaredFromConfig(value);
        }
        if (std.mem.eql(u8, cli_name, "react/no-unused-prop-types")) {
            self.react_no_unused_prop_types_skip_shape_props = try reactNoUnusedPropTypesSkipShapePropsFromConfig(value);
        }
        if (std.mem.eql(u8, cli_name, "react/no-string-refs")) {
            self.react_no_string_refs_no_template_literals = try reactNoStringRefsNoTemplateLiteralsFromConfig(value);
        }
        if (std.mem.eql(u8, cli_name, "react/no-multi-comp")) {
            self.react_no_multi_comp_ignore_stateless = try reactNoMultiCompIgnoreStatelessFromConfig(value);
        }
        if (std.mem.eql(u8, cli_name, "react/no-unknown-property")) {
            self.react_no_unknown_property_ignore = try reactNoUnknownPropertyIgnoreFromConfig(value);
            self.react_no_unknown_property_require_data_lowercase = try reactNoUnknownPropertyRequireDataLowercaseFromConfig(value);
        }
        if (std.mem.eql(u8, cli_name, "react/no-unescaped-entities")) {
            const forbid = try reactNoUnescapedEntitiesForbidFromConfig(value);
            self.react_no_unescaped_entities_forbid_gt = forbid.gt;
            self.react_no_unescaped_entities_forbid_double_quote = forbid.double_quote;
            self.react_no_unescaped_entities_forbid_single_quote = forbid.single_quote;
            self.react_no_unescaped_entities_forbid_closing_brace = forbid.closing_brace;
        }
        if (std.mem.eql(u8, cli_name, "react/prefer-es6-class")) {
            self.react_prefer_es6_class_style = try reactPreferEs6ClassStyleFromConfig(value);
        }
        if (std.mem.eql(u8, cli_name, "react/self-closing-comp")) {
            self.react_self_closing_comp_component = try reactSelfClosingCompBoolOptionFromConfig(value, "component", true);
            self.react_self_closing_comp_html = try reactSelfClosingCompBoolOptionFromConfig(value, "html", true);
        }
        if (std.mem.eql(u8, cli_name, "@typescript-eslint/array-type")) {
            self.typescript_eslint_array_type_style = try typescriptEslintArrayTypeStyleFromConfig(value);
        }
        if (std.mem.eql(u8, cli_name, "@typescript-eslint/ban-types")) {
            self.typescript_eslint_ban_types_config = try typescriptEslintBanTypesConfigFromConfig(value);
        }
        if (std.mem.eql(u8, cli_name, "@typescript-eslint/ban-ts-comment")) {
            self.typescript_eslint_ban_ts_comment_ts_expect_error = try typescriptEslintBanTsCommentModeFromConfig(value, "ts-expect-error", .allow_with_description);
            self.typescript_eslint_ban_ts_comment_ts_ignore = try typescriptEslintBanTsCommentModeFromConfig(value, "ts-ignore", .allow_with_description);
            self.typescript_eslint_ban_ts_comment_ts_nocheck = try typescriptEslintBanTsCommentModeFromConfig(value, "ts-nocheck", .allow_with_description);
            self.typescript_eslint_ban_ts_comment_ts_check = try typescriptEslintBanTsCommentModeFromConfig(value, "ts-check", .allow_with_description);
            self.typescript_eslint_ban_ts_comment_minimum_description_length = try typescriptEslintBanTsCommentMinimumDescriptionLengthFromConfig(value);
        }
        if (std.mem.eql(u8, cli_name, "@typescript-eslint/class-literal-property-style")) {
            self.typescript_eslint_class_literal_property_style_style = try typescriptEslintClassLiteralPropertyStyleFromConfig(value);
        }
        if (std.mem.eql(u8, cli_name, "@typescript-eslint/consistent-type-definitions")) {
            self.typescript_eslint_consistent_type_definitions_style = try typescriptEslintConsistentTypeDefinitionsStyleFromConfig(value);
        }
        if (std.mem.eql(u8, cli_name, "@typescript-eslint/consistent-type-assertions")) {
            self.typescript_eslint_consistent_type_assertions_assertion_style = try typescriptEslintConsistentTypeAssertionsStyleFromConfig(value);
            self.typescript_eslint_consistent_type_assertions_object_literal_type_assertions = try typescriptEslintLiteralTypeAssertionsFromConfig(value, "objectLiteralTypeAssertions", .never);
            self.typescript_eslint_consistent_type_assertions_array_literal_type_assertions = try typescriptEslintLiteralTypeAssertionsFromConfig(value, "arrayLiteralTypeAssertions", .allow);
        }
        if (std.mem.eql(u8, cli_name, "@typescript-eslint/explicit-member-accessibility")) {
            self.typescript_eslint_explicit_member_accessibility_accessibility = try typescriptEslintExplicitMemberAccessibilityFromConfig(value);
        }
        if (std.mem.eql(u8, cli_name, "@typescript-eslint/no-empty-interface")) {
            self.typescript_eslint_no_empty_interface_allow_single_extends = try typescriptEslintNoEmptyInterfaceAllowSingleExtendsFromConfig(value);
        }
        if (std.mem.eql(u8, cli_name, "@typescript-eslint/no-inferrable-types")) {
            self.typescript_eslint_no_inferrable_types_ignore_parameters = try typescriptEslintNoInferrableTypesBoolOptionFromConfig(value, "ignoreParameters", false);
            self.typescript_eslint_no_inferrable_types_ignore_properties = try typescriptEslintNoInferrableTypesBoolOptionFromConfig(value, "ignoreProperties", false);
        }
        if (std.mem.eql(u8, cli_name, "@typescript-eslint/no-invalid-void-type")) {
            self.typescript_eslint_no_invalid_void_type_allow_as_this_parameter = try typescriptEslintNoInvalidVoidTypeBoolOptionFromConfig(value, "allowAsThisParameter", false);
            self.typescript_eslint_no_invalid_void_type_allow_in_generic_type_arguments = try typescriptEslintNoInvalidVoidTypeBoolOptionFromConfig(value, "allowInGenericTypeArguments", true);
        }
        if (std.mem.eql(u8, cli_name, "@typescript-eslint/no-shadow")) {
            self.typescript_eslint_no_shadow_allow = try noShadowAllowFromConfig(value);
            self.typescript_eslint_no_shadow_builtin_globals = try noShadowBuiltinGlobalsFromConfig(value);
            self.typescript_eslint_no_shadow_hoist = try noShadowHoistFromConfig(value, .functions_and_types);
            self.typescript_eslint_no_shadow_ignore_on_initialization = try noShadowBoolOptionFromConfig(value, "ignoreOnInitialization", false);
            self.typescript_eslint_no_shadow_ignore_type_value_shadow = try noShadowBoolOptionFromConfig(value, "ignoreTypeValueShadow", false);
            self.typescript_eslint_no_shadow_ignore_function_type_parameter_name_value_shadow = try noShadowBoolOptionFromConfig(value, "ignoreFunctionTypeParameterNameValueShadow", true);
        }
        if (std.mem.eql(u8, cli_name, "@typescript-eslint/method-signature-style")) {
            self.typescript_eslint_method_signature_style_style = try typescriptEslintMethodSignatureStyleFromConfig(value);
        }
        if (std.mem.eql(u8, cli_name, "@typescript-eslint/no-namespace")) {
            self.typescript_eslint_no_namespace_allow_declarations = try typescriptEslintNoNamespaceBoolOptionFromConfig(value, "allowDeclarations", true);
            self.typescript_eslint_no_namespace_allow_definition_files = try typescriptEslintNoNamespaceBoolOptionFromConfig(value, "allowDefinitionFiles", true);
        }
        if (std.mem.eql(u8, cli_name, "@typescript-eslint/no-redeclare")) {
            self.typescript_eslint_no_redeclare_builtin_globals = try typescriptEslintNoRedeclareBuiltinGlobalsFromConfig(value);
            self.typescript_eslint_no_redeclare_ignore_declaration_merge = try typescriptEslintNoRedeclareIgnoreDeclarationMergeFromConfig(value);
        }
        if (std.mem.eql(u8, cli_name, "@typescript-eslint/no-this-alias")) {
            self.typescript_eslint_no_this_alias_allowed_names = try typescriptEslintNoThisAliasAllowedNamesFromConfig(value);
        }
        if (std.mem.eql(u8, cli_name, "@typescript-eslint/no-unused-vars")) {
            self.typescript_eslint_no_unused_vars_vars = try noUnusedVarsVarsFromConfig(value, .all);
            self.typescript_eslint_no_unused_vars_args = try noUnusedVarsArgsFromConfig(value, .after_used);
            self.typescript_eslint_no_unused_vars_caught_errors = try noUnusedVarsCaughtErrorsFromConfig(value, .all);
            self.typescript_eslint_no_unused_vars_ignore_rest_siblings = try noUnusedVarsIgnoreRestSiblingsFromConfig(value, true);
            self.typescript_eslint_no_unused_vars_ignore_class_with_static_init_block = try noUnusedVarsBoolOptionFromConfig(value, "ignoreClassWithStaticInitBlock", false);
            self.typescript_eslint_no_unused_vars_ignore_using_declarations = try noUnusedVarsBoolOptionFromConfig(value, "ignoreUsingDeclarations", false);
            self.typescript_eslint_no_unused_vars_args_ignore_pattern = try noUnusedVarsIgnorePatternFromConfig(value, "argsIgnorePattern");
            self.typescript_eslint_no_unused_vars_caught_errors_ignore_pattern = try noUnusedVarsIgnorePatternFromConfig(value, "caughtErrorsIgnorePattern");
            self.typescript_eslint_no_unused_vars_destructured_array_ignore_pattern = try noUnusedVarsIgnorePatternFromConfig(value, "destructuredArrayIgnorePattern");
            self.typescript_eslint_no_unused_vars_report_used_ignore_pattern = try noUnusedVarsReportUsedIgnorePatternFromConfig(value, false);
            self.typescript_eslint_no_unused_vars_vars_ignore_pattern = try noUnusedVarsIgnorePatternFromConfig(value, "varsIgnorePattern");
        }
        if (std.mem.eql(u8, cli_name, "@typescript-eslint/triple-slash-reference")) {
            self.typescript_eslint_triple_slash_reference_path = try typescriptEslintTripleSlashReferenceModeFromConfig(value, "path", .never);
            self.typescript_eslint_triple_slash_reference_types = try typescriptEslintTripleSlashReferenceModeFromConfig(value, "types", .always);
            self.typescript_eslint_triple_slash_reference_lib = try typescriptEslintTripleSlashReferenceModeFromConfig(value, "lib", .always);
        }
        if (std.mem.eql(u8, cli_name, "@typescript-eslint/typedef")) {
            self.typescript_eslint_typedef_property_declaration = try typescriptEslintTypedefBoolOptionFromConfig(value, "propertyDeclaration", true);
            self.typescript_eslint_typedef_member_variable_declaration = try typescriptEslintTypedefBoolOptionFromConfig(value, "memberVariableDeclaration", false);
            self.typescript_eslint_typedef_parameter = try typescriptEslintTypedefBoolOptionFromConfig(value, "parameter", false);
            self.typescript_eslint_typedef_arrow_parameter = try typescriptEslintTypedefBoolOptionFromConfig(value, "arrowParameter", false);
            self.typescript_eslint_typedef_array_destructuring = try typescriptEslintTypedefBoolOptionFromConfig(value, "arrayDestructuring", false);
            self.typescript_eslint_typedef_object_destructuring = try typescriptEslintTypedefBoolOptionFromConfig(value, "objectDestructuring", false);
            self.typescript_eslint_typedef_variable_declaration = try typescriptEslintTypedefBoolOptionFromConfig(value, "variableDeclaration", false);
            self.typescript_eslint_typedef_variable_declaration_ignore_function = try typescriptEslintTypedefBoolOptionFromConfig(value, "variableDeclarationIgnoreFunction", false);
        }
        if (std.mem.eql(u8, cli_name, "@typescript-eslint/restrict-plus-operands")) {
            self.typescript_eslint_restrict_plus_operands_allow_number_and_string = try typescriptEslintRestrictPlusOperandsBoolOptionFromConfig(value, "allowNumberAndString", false);
        }
        if (std.mem.eql(u8, cli_name, "no-undef")) {
            self.no_undef_typeof = try noUndefTypeofFromConfig(value);
        }
        if (std.mem.eql(u8, cli_name, "no-tabs")) {
            self.no_tabs_allow_indentation_tabs = try noTabsAllowIndentationTabsFromConfig(value);
        }
        if (std.mem.eql(u8, cli_name, "no-unneeded-ternary")) {
            self.no_unneeded_ternary_default_assignment = try noUnneededTernaryDefaultAssignmentFromConfig(value);
        }
        if (std.mem.eql(u8, cli_name, "@typescript-eslint/no-use-before-define")) {
            self.typescript_eslint_no_use_before_define_check_functions = try noUseBeforeDefineCheckFromConfig(value, "functions", false);
            self.typescript_eslint_no_use_before_define_check_classes = try noUseBeforeDefineCheckFromConfig(value, "classes", true);
            self.typescript_eslint_no_use_before_define_check_variables = try noUseBeforeDefineCheckFromConfig(value, "variables", true);
            self.typescript_eslint_no_use_before_define_check_typedefs = try noUseBeforeDefineCheckFromConfig(value, "typedefs", true);
            self.typescript_eslint_no_use_before_define_check_enums = try noUseBeforeDefineCheckFromConfig(value, "enums", true);
            self.typescript_eslint_no_use_before_define_allow_named_exports = try noUseBeforeDefineAllowNamedExportsFromConfig(value);
            self.typescript_eslint_no_use_before_define_ignore_type_references = try noUseBeforeDefineBoolOptionFromConfig(value, "ignoreTypeReferences", true);
        }
        if (std.mem.eql(u8, cli_name, "no-void")) {
            self.no_void_allow_as_statement = try noVoidAllowAsStatementFromConfig(value);
        }
        if (std.mem.eql(u8, cli_name, "no-warning-comments")) {
            self.no_warning_comments_location = try noWarningCommentsLocationFromConfig(value);
            self.no_warning_comments_decoration = try noWarningCommentsDecorationFromConfig(value);
            self.no_warning_comments_terms = try noWarningCommentsTermsFromConfig(value);
        }
        if (std.mem.eql(u8, cli_name, "valid-typeof")) {
            self.valid_typeof_require_string_literals = try validTypeofRequireStringLiteralsFromConfig(value);
        }
        if (std.mem.eql(u8, cli_name, "spaced-comment")) {
            self.spaced_comment_style = try spacedCommentStyleFromConfig(value);
            self.spaced_comment_markers = try spacedCommentMarkersFromConfig(value);
            self.spaced_comment_exceptions = try spacedCommentExceptionsFromConfig(value);
        }
        if (std.mem.eql(u8, cli_name, "wrap-iife")) {
            self.wrap_iife_style = try wrapIifeStyleFromConfig(value);
        }
        if (std.mem.eql(u8, cli_name, "yoda")) {
            self.yoda_style = try yodaStyleFromConfig(value);
            self.yoda_only_equality = try yodaOnlyEqualityFromConfig(value);
            self.yoda_except_range = try yodaExceptRangeFromConfig(value);
        }
    }

    pub const RuleConfigError = error{
        EmptyRuleConfigArray,
        UnknownRule,
        UnsupportedRuleConfigValue,
    };

    fn ruleConfigValueToBool(value: std.json.Value) RuleConfigError!bool {
        return switch (value) {
            .bool => |enabled| enabled,
            .integer => |severity| switch (severity) {
                0 => false,
                1, 2 => true,
                else => error.UnsupportedRuleConfigValue,
            },
            .string => |severity| ruleSeverityStringToBool(severity) orelse error.UnsupportedRuleConfigValue,
            .array => |items| {
                if (items.items.len == 0) return error.EmptyRuleConfigArray;
                return ruleConfigValueToBool(items.items[0]);
            },
            else => error.UnsupportedRuleConfigValue,
        };
    }

    fn ruleSeverityStringToBool(severity: []const u8) ?bool {
        if (std.ascii.eqlIgnoreCase(severity, "off") or std.mem.eql(u8, severity, "0")) return false;
        if (std.ascii.eqlIgnoreCase(severity, "warn") or
            std.ascii.eqlIgnoreCase(severity, "warning") or
            std.ascii.eqlIgnoreCase(severity, "error") or
            std.ascii.eqlIgnoreCase(severity, "on") or
            std.mem.eql(u8, severity, "1") or
            std.mem.eql(u8, severity, "2"))
        {
            return true;
        }
        return null;
    }

    fn curlyStyleFromConfig(value: std.json.Value) RuleConfigError!CurlyStyle {
        const items = switch (value) {
            .array => |array| array.items,
            else => return .all,
        };
        if (items.len < 2) return .all;

        const style = switch (items[1]) {
            .string => |style| style,
            else => return error.UnsupportedRuleConfigValue,
        };
        if (std.mem.eql(u8, style, "all")) return .all;
        if (std.mem.eql(u8, style, "multi-line")) return .multi_line;
        if (std.mem.eql(u8, style, "multi")) return .multi;
        return error.UnsupportedRuleConfigValue;
    }

    fn eolLastStyleFromConfig(value: std.json.Value) RuleConfigError!EolLastStyle {
        const items = switch (value) {
            .array => |array| array.items,
            else => return .always,
        };
        if (items.len < 2) return .always;

        const style = switch (items[1]) {
            .string => |style| style,
            else => return error.UnsupportedRuleConfigValue,
        };
        if (std.mem.eql(u8, style, "always") or std.mem.eql(u8, style, "unix") or std.mem.eql(u8, style, "windows")) return .always;
        if (std.mem.eql(u8, style, "never")) return .never;
        return error.UnsupportedRuleConfigValue;
    }

    fn eqeqeqStyleFromConfig(value: std.json.Value) RuleConfigError!EqeqeqStyle {
        const items = switch (value) {
            .array => |array| array.items,
            else => return .strict,
        };
        if (items.len < 2) return .strict;

        const style = switch (items[1]) {
            .string => |style| style,
            else => return error.UnsupportedRuleConfigValue,
        };
        if (std.mem.eql(u8, style, "always")) return .strict;
        if (std.mem.eql(u8, style, "allow-null")) return .allow_null;
        if (std.mem.eql(u8, style, "smart")) return .smart;
        return error.UnsupportedRuleConfigValue;
    }

    fn linebreakStyleFromConfig(value: std.json.Value) RuleConfigError!LinebreakStyle {
        const items = switch (value) {
            .array => |array| array.items,
            else => return .unix,
        };
        if (items.len < 2) return .unix;

        const style = switch (items[1]) {
            .string => |style| style,
            else => return error.UnsupportedRuleConfigValue,
        };
        if (std.mem.eql(u8, style, "unix")) return .unix;
        if (std.mem.eql(u8, style, "windows")) return .windows;
        return error.UnsupportedRuleConfigValue;
    }

    fn consistentReturnTreatUndefinedAsUnspecifiedFromConfig(value: std.json.Value) RuleConfigError!bool {
        const items = switch (value) {
            .array => |array| array.items,
            else => return false,
        };
        if (items.len < 2) return false;

        const config = switch (items[1]) {
            .object => |object| object,
            else => return error.UnsupportedRuleConfigValue,
        };
        return switch (config.get("treatUndefinedAsUnspecified") orelse return false) {
            .bool => |enabled| enabled,
            else => error.UnsupportedRuleConfigValue,
        };
    }

    fn accessorPairsGetWithoutSetFromConfig(value: std.json.Value) RuleConfigError!AccessorPairsGetWithoutSet {
        const enabled = try accessorPairsOptionFromConfig(value, "getWithoutSet", false);
        return if (enabled) .yes else .no;
    }

    fn accessorPairsSetWithoutGetFromConfig(value: std.json.Value) RuleConfigError!AccessorPairsSetWithoutGet {
        const enabled = try accessorPairsOptionFromConfig(value, "setWithoutGet", true);
        return if (enabled) .yes else .no;
    }

    fn accessorPairsEnforceForClassMembersFromConfig(value: std.json.Value) RuleConfigError!AccessorPairsEnforceForClassMembers {
        const enabled = try accessorPairsOptionFromConfig(value, "enforceForClassMembers", true);
        return if (enabled) .yes else .no;
    }

    fn accessorPairsOptionFromConfig(value: std.json.Value, key: []const u8, default: bool) RuleConfigError!bool {
        const items = switch (value) {
            .array => |array| array.items,
            else => return default,
        };
        if (items.len < 2) return default;

        const config = switch (items[1]) {
            .object => |object| object,
            else => return error.UnsupportedRuleConfigValue,
        };
        return switch (config.get(key) orelse return default) {
            .bool => |enabled| enabled,
            else => error.UnsupportedRuleConfigValue,
        };
    }

    fn arrayCallbackReturnAllowImplicitFromConfig(value: std.json.Value) RuleConfigError!ArrayCallbackReturnAllowImplicit {
        const enabled = try arrayCallbackReturnOptionFromConfig(value, "allowImplicit", false);
        return if (enabled) .yes else .no;
    }

    fn arrayCallbackReturnCheckForEachFromConfig(value: std.json.Value) RuleConfigError!ArrayCallbackReturnCheckForEach {
        const enabled = try arrayCallbackReturnOptionFromConfig(value, "checkForEach", false);
        return if (enabled) .yes else .no;
    }

    fn arrayCallbackReturnAllowVoidFromConfig(value: std.json.Value) RuleConfigError!ArrayCallbackReturnAllowVoid {
        const enabled = try arrayCallbackReturnOptionFromConfig(value, "allowVoid", false);
        return if (enabled) .yes else .no;
    }

    fn arrayCallbackReturnOptionFromConfig(value: std.json.Value, key: []const u8, default: bool) RuleConfigError!bool {
        const items = switch (value) {
            .array => |array| array.items,
            else => return default,
        };
        if (items.len < 2) return default;

        const config = switch (items[1]) {
            .object => |object| object,
            else => return error.UnsupportedRuleConfigValue,
        };
        return switch (config.get(key) orelse return default) {
            .bool => |enabled| enabled,
            else => error.UnsupportedRuleConfigValue,
        };
    }

    fn capitalizedCommentsModeFromConfig(value: std.json.Value) RuleConfigError!CapitalizedCommentsMode {
        const items = switch (value) {
            .array => |array| array.items,
            else => return .always,
        };
        if (items.len < 2) return .always;

        const mode = switch (items[1]) {
            .string => |mode| mode,
            .object => return .always,
            else => return error.UnsupportedRuleConfigValue,
        };
        if (std.mem.eql(u8, mode, "always")) return .always;
        if (std.mem.eql(u8, mode, "never")) return .never;
        return error.UnsupportedRuleConfigValue;
    }

    fn capitalizedCommentsIgnoreInlineCommentsFromConfig(value: std.json.Value) RuleConfigError!CapitalizedCommentsIgnoreInlineComments {
        const ignore = try capitalizedCommentsBoolOptionFromConfig(value, "ignoreInlineComments", false);
        return if (ignore) .yes else .no;
    }

    fn capitalizedCommentsIgnoreConsecutiveCommentsFromConfig(value: std.json.Value) RuleConfigError!CapitalizedCommentsIgnoreConsecutiveComments {
        const ignore = try capitalizedCommentsBoolOptionFromConfig(value, "ignoreConsecutiveComments", false);
        return if (ignore) .yes else .no;
    }

    fn capitalizedCommentsBoolOptionFromConfig(value: std.json.Value, key: []const u8, default: bool) RuleConfigError!bool {
        const items = switch (value) {
            .array => |array| array.items,
            else => return default,
        };
        if (items.len < 2) return default;

        const config_value = switch (items[1]) {
            .object => items[1],
            .string => if (items.len >= 3) items[2] else return default,
            else => return error.UnsupportedRuleConfigValue,
        };
        const config = switch (config_value) {
            .object => |object| object,
            else => return error.UnsupportedRuleConfigValue,
        };
        return switch (config.get(key) orelse return default) {
            .bool => |enabled| enabled,
            else => return error.UnsupportedRuleConfigValue,
        };
    }

    fn deprecatedDependenceProfileFromConfig(value: std.json.Value) DeprecatedDependenceProfile {
        const items = switch (value) {
            .array => |array| array.items,
            else => return .default,
        };
        if (items.len < 2) return .default;
        const config = switch (items[1]) {
            .object => |object| object,
            else => return .default,
        };
        const external_packages = switch (config.get("externalPackages") orelse return .default) {
            .object => |object| object,
            else => return .default,
        };

        if (external_packages.get("@example/share-react") != null or
            external_packages.get("@example/monitor-web") != null or
            external_packages.get("moment") != null)
        {
            return .profile_a;
        }
        if (external_packages.get("@example/bridge") != null or
            external_packages.get("@example/rpc-client") != null or
            external_packages.get("statekit") != null)
        {
            return .profile_b;
        }
        return .default;
    }

    fn dotNotationAllowKeywordsFromConfig(value: std.json.Value) RuleConfigError!DotNotationAllowKeywords {
        const items = switch (value) {
            .array => |array| array.items,
            else => return .yes,
        };
        if (items.len < 2) return .yes;

        const config = switch (items[1]) {
            .object => |object| object,
            else => return error.UnsupportedRuleConfigValue,
        };
        const allow = switch (config.get("allowKeywords") orelse return .yes) {
            .bool => |enabled| enabled,
            else => return error.UnsupportedRuleConfigValue,
        };
        return if (allow) .yes else .no;
    }

    fn dotNotationAllowPatternFromConfig(value: std.json.Value) RuleConfigError!DotNotationAllowPattern {
        const items = switch (value) {
            .array => |array| array.items,
            else => return .{},
        };
        if (items.len < 2) return .{};

        const config = switch (items[1]) {
            .object => |object| object,
            else => return error.UnsupportedRuleConfigValue,
        };
        const pattern_value = switch (config.get("allowPattern") orelse return .{}) {
            .string => |pattern_value| pattern_value,
            else => return error.UnsupportedRuleConfigValue,
        };
        if (pattern_value.len == 0) return .{};

        var pattern = DotNotationAllowPattern{};
        pattern.set(pattern_value) catch return error.UnsupportedRuleConfigValue;
        return pattern;
    }

    fn noRestrictedDisableRestrictsNoNestedTernary(value: std.json.Value) bool {
        const items = switch (value) {
            .array => |array| array.items,
            else => return false,
        };
        if (items.len < 2) return false;
        for (items[1..]) |item| {
            const rule = switch (item) {
                .string => |rule| rule,
                else => continue,
            };
            if (std.mem.eql(u8, rule, "no-nested-ternary")) return true;
        }
        return false;
    }

    fn funcNameMatchingStyleFromConfig(value: std.json.Value) RuleConfigError!FuncNameMatchingStyle {
        const items = switch (value) {
            .array => |array| array.items,
            else => return .always,
        };
        if (items.len < 2) return .always;

        const style = switch (items[1]) {
            .string => |style| style,
            else => return error.UnsupportedRuleConfigValue,
        };
        if (std.mem.eql(u8, style, "always")) return .always;
        if (std.mem.eql(u8, style, "never")) return .never;
        return error.UnsupportedRuleConfigValue;
    }

    fn funcNamesStyleFromConfig(value: std.json.Value) RuleConfigError!FuncNamesStyle {
        const items = switch (value) {
            .array => |array| array.items,
            else => return .always,
        };
        if (items.len < 2) return .always;

        const style = switch (items[1]) {
            .string => |style| style,
            else => return error.UnsupportedRuleConfigValue,
        };
        if (std.mem.eql(u8, style, "always")) return .always;
        if (std.mem.eql(u8, style, "as-needed")) return .as_needed;
        if (std.mem.eql(u8, style, "never")) return .never;
        return error.UnsupportedRuleConfigValue;
    }

    fn funcNamesGeneratorStyleFromConfig(value: std.json.Value) RuleConfigError!?FuncNamesStyle {
        const items = switch (value) {
            .array => |array| array.items,
            else => return null,
        };
        if (items.len < 3) return null;

        const config = switch (items[2]) {
            .object => |object| object,
            else => return error.UnsupportedRuleConfigValue,
        };
        const style = switch (config.get("generators") orelse return null) {
            .string => |style| style,
            else => return error.UnsupportedRuleConfigValue,
        };
        if (std.mem.eql(u8, style, "always")) return .always;
        if (std.mem.eql(u8, style, "as-needed")) return .as_needed;
        if (std.mem.eql(u8, style, "never")) return .never;
        return error.UnsupportedRuleConfigValue;
    }

    fn groupedAccessorPairsStyleFromConfig(value: std.json.Value) RuleConfigError!GroupedAccessorPairsStyle {
        const items = switch (value) {
            .array => |array| array.items,
            else => return .any_order,
        };
        if (items.len < 2) return .any_order;

        const style = switch (items[1]) {
            .string => |style| style,
            else => return error.UnsupportedRuleConfigValue,
        };
        if (std.mem.eql(u8, style, "anyOrder")) return .any_order;
        if (std.mem.eql(u8, style, "getBeforeSet")) return .get_before_set;
        if (std.mem.eql(u8, style, "setBeforeGet")) return .set_before_get;
        return error.UnsupportedRuleConfigValue;
    }

    fn reactNoUnusedPropTypesSkipShapePropsFromConfig(value: std.json.Value) RuleConfigError!bool {
        const items = switch (value) {
            .array => |array| array.items,
            else => return true,
        };
        if (items.len < 2) return true;

        const config = switch (items[1]) {
            .object => |object| object,
            else => return error.UnsupportedRuleConfigValue,
        };
        return switch (config.get("skipShapeProps") orelse return true) {
            .bool => |enabled| enabled,
            else => return error.UnsupportedRuleConfigValue,
        };
    }

    fn reactPropTypesSkipUndeclaredFromConfig(value: std.json.Value) RuleConfigError!bool {
        const items = switch (value) {
            .array => |array| array.items,
            else => return false,
        };
        if (items.len < 2) return false;

        const config = switch (items[1]) {
            .object => |object| object,
            else => return error.UnsupportedRuleConfigValue,
        };
        return switch (config.get("skipUndeclared") orelse return false) {
            .bool => |enabled| enabled,
            else => return error.UnsupportedRuleConfigValue,
        };
    }

    fn reactJsxNoTargetBlankAllowReferrerFromConfig(value: std.json.Value) RuleConfigError!bool {
        const items = switch (value) {
            .array => |array| array.items,
            else => return false,
        };
        if (items.len < 2) return false;

        const config = switch (items[1]) {
            .object => |object| object,
            else => return error.UnsupportedRuleConfigValue,
        };
        return switch (config.get("allowReferrer") orelse return false) {
            .bool => |enabled| enabled,
            else => return error.UnsupportedRuleConfigValue,
        };
    }

    fn reactJsxNoTargetBlankEnforceDynamicLinksFromConfig(value: std.json.Value) RuleConfigError!bool {
        const items = switch (value) {
            .array => |array| array.items,
            else => return true,
        };
        if (items.len < 2) return true;

        const config = switch (items[1]) {
            .object => |object| object,
            else => return error.UnsupportedRuleConfigValue,
        };
        const mode = switch (config.get("enforceDynamicLinks") orelse return true) {
            .string => |mode| mode,
            else => return error.UnsupportedRuleConfigValue,
        };
        if (std.mem.eql(u8, mode, "always")) return true;
        if (std.mem.eql(u8, mode, "never")) return false;
        return error.UnsupportedRuleConfigValue;
    }

    const ReactNoUnescapedEntitiesForbid = struct {
        gt: bool = true,
        double_quote: bool = true,
        single_quote: bool = true,
        closing_brace: bool = true,
    };

    fn reactNoUnescapedEntitiesForbidFromConfig(value: std.json.Value) RuleConfigError!ReactNoUnescapedEntitiesForbid {
        const items = switch (value) {
            .array => |array| array.items,
            else => return .{},
        };
        if (items.len < 2) return .{};

        const config = switch (items[1]) {
            .object => |object| object,
            else => return error.UnsupportedRuleConfigValue,
        };
        const forbid = switch (config.get("forbid") orelse return .{}) {
            .array => |array| array.items,
            else => return error.UnsupportedRuleConfigValue,
        };

        var result = ReactNoUnescapedEntitiesForbid{
            .gt = false,
            .double_quote = false,
            .single_quote = false,
            .closing_brace = false,
        };
        for (forbid) |entry| {
            const char = switch (entry) {
                .string => |string| string,
                .object => |object| switch (object.get("char") orelse return error.UnsupportedRuleConfigValue) {
                    .string => |string| string,
                    else => return error.UnsupportedRuleConfigValue,
                },
                else => return error.UnsupportedRuleConfigValue,
            };
            if (std.mem.eql(u8, char, ">")) {
                result.gt = true;
            } else if (std.mem.eql(u8, char, "\"")) {
                result.double_quote = true;
            } else if (std.mem.eql(u8, char, "'")) {
                result.single_quote = true;
            } else if (std.mem.eql(u8, char, "}")) {
                result.closing_brace = true;
            } else {
                return error.UnsupportedRuleConfigValue;
            }
        }
        return result;
    }

    fn typescriptEslintBanTypesConfigFromConfig(value: std.json.Value) RuleConfigError!TypescriptEslintBanTypesConfig {
        const items = switch (value) {
            .array => |array| array.items,
            else => return .{},
        };
        if (items.len < 2) return .{};

        const config_object = switch (items[1]) {
            .object => |object| object,
            else => return error.UnsupportedRuleConfigValue,
        };

        var config = TypescriptEslintBanTypesConfig{};
        config.extend_defaults = if (config_object.get("extendDefaults")) |extend_defaults| switch (extend_defaults) {
            .bool => |enabled| enabled,
            else => return error.UnsupportedRuleConfigValue,
        } else true;

        const types_value = config_object.get("types") orelse return config;
        const types = switch (types_value) {
            .object => |object| object,
            else => return error.UnsupportedRuleConfigValue,
        };

        var iter = types.iterator();
        while (iter.next()) |entry| {
            const name = entry.key_ptr.*;
            switch (entry.value_ptr.*) {
                .bool => |enabled| {
                    if (enabled) {
                        try appendBanTypeConfig(&config.custom, name, defaultBanTypeMessage(name));
                    } else {
                        try appendDisabledBanType(&config.disabled, name);
                    }
                },
                .string => |message| try appendBanTypeConfig(&config.custom, name, message),
                .object => |object| {
                    const message = if (object.get("message")) |message_value| switch (message_value) {
                        .string => |message| message,
                        else => return error.UnsupportedRuleConfigValue,
                    } else defaultBanTypeMessage(name);
                    try appendBanTypeConfig(&config.custom, name, message);
                },
                else => return error.UnsupportedRuleConfigValue,
            }
        }

        return config;
    }

    fn appendDisabledBanType(
        disabled: *TypescriptEslintBanTypeNames,
        name: []const u8,
    ) RuleConfigError!void {
        disabled.append(name) catch return error.UnsupportedRuleConfigValue;
    }

    fn appendBanTypeConfig(
        entries: *TypescriptEslintBanTypeEntries,
        name: []const u8,
        message: []const u8,
    ) RuleConfigError!void {
        entries.append(name, message) catch return error.UnsupportedRuleConfigValue;
    }

    fn defaultBanTypeMessage(name: []const u8) []const u8 {
        if (std.mem.eql(u8, name, "String")) return "Use string instead";
        if (std.mem.eql(u8, name, "Boolean")) return "Use boolean instead";
        if (std.mem.eql(u8, name, "Number")) return "Use number instead";
        if (std.mem.eql(u8, name, "Symbol")) return "Use symbol instead";
        if (std.mem.eql(u8, name, "BigInt")) return "Use bigint instead";
        if (std.mem.eql(u8, name, "Function")) return "The `Function` type accepts any function-like value.";
        if (std.mem.eql(u8, name, "Object")) return "Use object instead";
        if (std.mem.eql(u8, name, "object")) return "Use a more specific object type instead";
        if (std.mem.eql(u8, name, "{}")) return "Use a more specific object type instead";
        return "This type is banned.";
    }

    fn typescriptEslintConsistentTypeAssertionsStyleFromConfig(value: std.json.Value) RuleConfigError!TypescriptEslintConsistentTypeAssertionsStyle {
        const items = switch (value) {
            .array => |array| array.items,
            else => return .as,
        };
        if (items.len < 2) return .as;

        const config = switch (items[1]) {
            .object => |object| object,
            else => return error.UnsupportedRuleConfigValue,
        };
        const style = switch (config.get("assertionStyle") orelse return .as) {
            .string => |style| style,
            else => return error.UnsupportedRuleConfigValue,
        };
        if (std.mem.eql(u8, style, "as")) return .as;
        if (std.mem.eql(u8, style, "angle-bracket")) return .angle_bracket;
        if (std.mem.eql(u8, style, "never")) return .never;
        return error.UnsupportedRuleConfigValue;
    }

    fn typescriptEslintLiteralTypeAssertionsFromConfig(
        value: std.json.Value,
        key: []const u8,
        default: TypescriptEslintLiteralTypeAssertions,
    ) RuleConfigError!TypescriptEslintLiteralTypeAssertions {
        const items = switch (value) {
            .array => |array| array.items,
            else => return default,
        };
        if (items.len < 2) return default;

        const config = switch (items[1]) {
            .object => |object| object,
            else => return error.UnsupportedRuleConfigValue,
        };
        const style = switch (config.get(key) orelse return default) {
            .string => |style| style,
            else => return error.UnsupportedRuleConfigValue,
        };
        if (std.mem.eql(u8, style, "allow")) return .allow;
        if (std.mem.eql(u8, style, "allow-as-parameter")) return .allow_as_parameter;
        if (std.mem.eql(u8, style, "never")) return .never;
        return error.UnsupportedRuleConfigValue;
    }

    fn typescriptEslintExplicitMemberAccessibilityFromConfig(value: std.json.Value) RuleConfigError!TypescriptEslintExplicitMemberAccessibility {
        const items = switch (value) {
            .array => |array| array.items,
            else => return .no_public,
        };
        if (items.len < 2) return .no_public;

        const config = switch (items[1]) {
            .object => |object| object,
            else => return error.UnsupportedRuleConfigValue,
        };
        const accessibility = switch (config.get("accessibility") orelse return .no_public) {
            .string => |accessibility| accessibility,
            else => return error.UnsupportedRuleConfigValue,
        };
        if (std.mem.eql(u8, accessibility, "explicit")) return .explicit;
        if (std.mem.eql(u8, accessibility, "no-public")) return .no_public;
        if (std.mem.eql(u8, accessibility, "off")) return .off;
        return error.UnsupportedRuleConfigValue;
    }

    fn logicalAssignmentOperatorsStyleFromConfig(value: std.json.Value) RuleConfigError!LogicalAssignmentOperatorsStyle {
        const items = switch (value) {
            .array => |array| array.items,
            else => return .always,
        };
        if (items.len < 2) return .always;

        const style = switch (items[1]) {
            .string => |style| style,
            .object => return .always,
            else => return error.UnsupportedRuleConfigValue,
        };
        if (std.mem.eql(u8, style, "always")) return .always;
        if (std.mem.eql(u8, style, "never")) return .never;
        return error.UnsupportedRuleConfigValue;
    }

    fn logicalAssignmentOperatorsEnforceForIfStatementsFromConfig(value: std.json.Value) RuleConfigError!LogicalAssignmentOperatorsEnforceForIfStatements {
        const items = switch (value) {
            .array => |array| array.items,
            else => return .no,
        };
        if (items.len < 2) return .no;

        const config_value = switch (items[1]) {
            .object => items[1],
            .string => if (items.len >= 3) items[2] else return .no,
            else => return error.UnsupportedRuleConfigValue,
        };
        const config = switch (config_value) {
            .object => |object| object,
            else => return error.UnsupportedRuleConfigValue,
        };
        const enforce = switch (config.get("enforceForIfStatements") orelse return .no) {
            .bool => |enabled| enabled,
            else => return error.UnsupportedRuleConfigValue,
        };
        return if (enforce) .yes else .no;
    }

    fn newCapBoolOptionFromConfig(value: std.json.Value, key: []const u8, default: bool) RuleConfigError!bool {
        const items = switch (value) {
            .array => |array| array.items,
            else => return default,
        };
        if (items.len < 2) return default;

        const config = switch (items[1]) {
            .object => |object| object,
            else => return error.UnsupportedRuleConfigValue,
        };
        return switch (config.get(key) orelse return default) {
            .bool => |enabled| enabled,
            else => error.UnsupportedRuleConfigValue,
        };
    }

    fn newCapExceptionNamesFromConfig(value: std.json.Value, key: []const u8) RuleConfigError!NewCapExceptionNames {
        const items = switch (value) {
            .array => |array| array.items,
            else => return .{},
        };
        if (items.len < 2) return .{};

        const config = switch (items[1]) {
            .object => |object| object,
            else => return error.UnsupportedRuleConfigValue,
        };
        const exception_value = config.get(key) orelse return .{};
        const exception_items = switch (exception_value) {
            .array => |array| array.items,
            else => return error.UnsupportedRuleConfigValue,
        };

        var exceptions = NewCapExceptionNames{};
        for (exception_items) |item| {
            const name = switch (item) {
                .string => |name| name,
                else => return error.UnsupportedRuleConfigValue,
            };
            exceptions.append(name) catch return error.UnsupportedRuleConfigValue;
        }
        return exceptions;
    }

    fn newCapExceptionPatternFromConfig(value: std.json.Value, key: []const u8) RuleConfigError!NewCapExceptionPattern {
        const items = switch (value) {
            .array => |array| array.items,
            else => return .{},
        };
        if (items.len < 2) return .{};

        const config = switch (items[1]) {
            .object => |object| object,
            else => return error.UnsupportedRuleConfigValue,
        };
        const pattern_value = switch (config.get(key) orelse return .{}) {
            .string => |pattern_value| pattern_value,
            else => return error.UnsupportedRuleConfigValue,
        };
        if (pattern_value.len == 0) return .{};

        var pattern = NewCapExceptionPattern{};
        pattern.set(pattern_value) catch return error.UnsupportedRuleConfigValue;
        return pattern;
    }

    fn defaultCaseCommentPatternFromConfig(value: std.json.Value) RuleConfigError!DefaultCaseCommentPattern {
        const items = switch (value) {
            .array => |array| array.items,
            else => return .{},
        };
        if (items.len < 2) return .{};

        const config = switch (items[1]) {
            .object => |object| object,
            else => return error.UnsupportedRuleConfigValue,
        };
        const pattern_value = switch (config.get("commentPattern") orelse return .{}) {
            .string => |pattern_value| pattern_value,
            else => return error.UnsupportedRuleConfigValue,
        };

        var pattern = DefaultCaseCommentPattern{};
        pattern.set(pattern_value) catch return error.UnsupportedRuleConfigValue;
        return pattern;
    }

    fn noBitwiseAllowFromConfig(value: std.json.Value, expected: []const u8) RuleConfigError!bool {
        const items = switch (value) {
            .array => |array| array.items,
            else => return false,
        };
        if (items.len < 2) return false;

        const config = switch (items[1]) {
            .object => |object| object,
            else => return error.UnsupportedRuleConfigValue,
        };
        const allow_value = config.get("allow") orelse return false;
        const allow_items = switch (allow_value) {
            .array => |array| array.items,
            else => return error.UnsupportedRuleConfigValue,
        };

        for (allow_items) |item| {
            const operator = switch (item) {
                .string => |operator| operator,
                else => return error.UnsupportedRuleConfigValue,
            };
            if (!isNoBitwiseOperatorToken(operator)) return error.UnsupportedRuleConfigValue;
            if (std.mem.eql(u8, operator, expected)) return true;
        }

        return false;
    }

    fn noBitwiseInt32HintFromConfig(value: std.json.Value) RuleConfigError!bool {
        const items = switch (value) {
            .array => |array| array.items,
            else => return false,
        };
        if (items.len < 2) return false;

        const config = switch (items[1]) {
            .object => |object| object,
            else => return error.UnsupportedRuleConfigValue,
        };
        return switch (config.get("int32Hint") orelse return false) {
            .bool => |enabled| enabled,
            else => error.UnsupportedRuleConfigValue,
        };
    }

    fn noUselessEscapeAllowRegexCharactersFromConfig(value: std.json.Value) RuleConfigError!NoUselessEscapeAllowRegexCharacters {
        const items = switch (value) {
            .array => |array| array.items,
            else => return .{},
        };
        if (items.len < 2) return .{};

        const config = switch (items[1]) {
            .object => |object| object,
            else => return error.UnsupportedRuleConfigValue,
        };
        const allow_value = config.get("allowRegexCharacters") orelse return .{};
        const allow_items = switch (allow_value) {
            .array => |array| array.items,
            else => return error.UnsupportedRuleConfigValue,
        };

        var allow = NoUselessEscapeAllowRegexCharacters{};
        for (allow_items) |item| {
            const character = switch (item) {
                .string => |character| character,
                else => return error.UnsupportedRuleConfigValue,
            };
            allow.append(character) catch return error.UnsupportedRuleConfigValue;
        }
        return allow;
    }

    fn noInvalidRegexpAllowConstructorFlagsFromConfig(value: std.json.Value) RuleConfigError!NoInvalidRegexpAllowConstructorFlags {
        const items = switch (value) {
            .array => |array| array.items,
            else => return .{},
        };
        if (items.len < 2) return .{};

        const config = switch (items[1]) {
            .object => |object| object,
            else => return error.UnsupportedRuleConfigValue,
        };
        const allow_value = config.get("allowConstructorFlags") orelse return .{};
        const allow_items = switch (allow_value) {
            .array => |array| array.items,
            else => return error.UnsupportedRuleConfigValue,
        };

        var allow: NoInvalidRegexpAllowConstructorFlags = .{};
        for (allow_items) |item| {
            const flag = switch (item) {
                .string => |flag| flag,
                else => return error.UnsupportedRuleConfigValue,
            };
            if (!allow.enable(flag)) return error.UnsupportedRuleConfigValue;
        }
        return allow;
    }

    fn isNoBitwiseOperatorToken(operator: []const u8) bool {
        inline for (.{ "&", "|", "^", "~", "<<", ">>", ">>>" }) |allowed| {
            if (std.mem.eql(u8, operator, allowed)) return true;
        }
        return false;
    }

    fn noConsoleAllowFromConfig(value: std.json.Value) RuleConfigError!NoConsoleAllow {
        const items = switch (value) {
            .array => |array| array.items,
            else => return .{},
        };
        if (items.len < 2) return .{};

        const config = switch (items[1]) {
            .object => |object| object,
            else => return error.UnsupportedRuleConfigValue,
        };
        const allow_value = config.get("allow") orelse return .{};
        const allow_items = switch (allow_value) {
            .array => |array| array.items,
            else => return error.UnsupportedRuleConfigValue,
        };

        var allow: NoConsoleAllow = .{};
        for (allow_items) |item| {
            const method = switch (item) {
                .string => |method| method,
                else => return error.UnsupportedRuleConfigValue,
            };
            if (!allow.enable(method)) return error.UnsupportedRuleConfigValue;
        }
        return allow;
    }

    fn noCondAssignStyleFromConfig(value: std.json.Value) RuleConfigError!NoCondAssignStyle {
        const items = switch (value) {
            .array => |array| array.items,
            else => return .except_parens,
        };
        if (items.len < 2) return .except_parens;

        const style = switch (items[1]) {
            .string => |style| style,
            else => return error.UnsupportedRuleConfigValue,
        };
        if (std.mem.eql(u8, style, "except-parens")) return .except_parens;
        if (std.mem.eql(u8, style, "always")) return .always;
        return error.UnsupportedRuleConfigValue;
    }

    fn noConstantConditionCheckLoopsFromConfig(value: std.json.Value) RuleConfigError!NoConstantConditionCheckLoops {
        const items = switch (value) {
            .array => |array| array.items,
            else => return .all_except_while_true,
        };
        if (items.len < 2) return .all_except_while_true;

        const config = switch (items[1]) {
            .object => |object| object,
            else => return error.UnsupportedRuleConfigValue,
        };
        const check_loops = config.get("checkLoops") orelse return .all_except_while_true;
        return switch (check_loops) {
            .bool => |enabled| if (enabled) .all else .none,
            .string => |style| {
                if (std.mem.eql(u8, style, "all")) return .all;
                if (std.mem.eql(u8, style, "allExceptWhileTrue")) return .all_except_while_true;
                if (std.mem.eql(u8, style, "none")) return .none;
                return error.UnsupportedRuleConfigValue;
            },
            else => error.UnsupportedRuleConfigValue,
        };
    }

    fn noConfusingArrowAllowParensFromConfig(value: std.json.Value) RuleConfigError!NoConfusingArrowAllowParens {
        const items = switch (value) {
            .array => |array| array.items,
            else => return .yes,
        };
        if (items.len < 2) return .yes;

        const config = switch (items[1]) {
            .object => |object| object,
            else => return error.UnsupportedRuleConfigValue,
        };
        const allow = switch (config.get("allowParens") orelse return .yes) {
            .bool => |enabled| enabled,
            else => return error.UnsupportedRuleConfigValue,
        };
        return if (allow) .yes else .no;
    }

    fn noEmptyAllowEmptyCatchFromConfig(value: std.json.Value) RuleConfigError!NoEmptyAllowEmptyCatch {
        const items = switch (value) {
            .array => |array| array.items,
            else => return .no,
        };
        if (items.len < 2) return .no;

        const config = switch (items[1]) {
            .object => |object| object,
            else => return error.UnsupportedRuleConfigValue,
        };
        const allow = switch (config.get("allowEmptyCatch") orelse return .no) {
            .bool => |enabled| enabled,
            else => return error.UnsupportedRuleConfigValue,
        };
        return if (allow) .yes else .no;
    }

    fn noEmptyFunctionAllowFromConfig(value: std.json.Value) RuleConfigError!NoEmptyFunctionAllow {
        const items = switch (value) {
            .array => |array| array.items,
            else => return .{},
        };
        if (items.len < 2) return .{};

        const config = switch (items[1]) {
            .object => |object| object,
            else => return error.UnsupportedRuleConfigValue,
        };
        const allow_value = config.get("allow") orelse return .{};
        const allow_items = switch (allow_value) {
            .array => |array| array.items,
            else => return error.UnsupportedRuleConfigValue,
        };

        var allow: NoEmptyFunctionAllow = .{};
        for (allow_items) |item| {
            const kind = switch (item) {
                .string => |kind| kind,
                else => return error.UnsupportedRuleConfigValue,
            };
            if (!allow.enable(kind)) return error.UnsupportedRuleConfigValue;
        }
        return allow;
    }

    fn noElseReturnAllowElseIfFromConfig(value: std.json.Value) RuleConfigError!bool {
        const items = switch (value) {
            .array => |array| array.items,
            else => return true,
        };
        if (items.len < 2) return true;

        const config = switch (items[1]) {
            .object => |object| object,
            else => return error.UnsupportedRuleConfigValue,
        };
        return switch (config.get("allowElseIf") orelse return true) {
            .bool => |enabled| enabled,
            else => error.UnsupportedRuleConfigValue,
        };
    }

    fn noEmptyPatternAllowObjectPatternsAsParametersFromConfig(value: std.json.Value) RuleConfigError!bool {
        const items = switch (value) {
            .array => |array| array.items,
            else => return false,
        };
        if (items.len < 2) return false;

        const config = switch (items[1]) {
            .object => |object| object,
            else => return error.UnsupportedRuleConfigValue,
        };
        return switch (config.get("allowObjectPatternsAsParameters") orelse return false) {
            .bool => |enabled| enabled,
            else => error.UnsupportedRuleConfigValue,
        };
    }

    fn noExtraBooleanCastEnforceForInnerExpressionsFromConfig(value: std.json.Value) RuleConfigError!bool {
        const items = switch (value) {
            .array => |array| array.items,
            else => return false,
        };
        if (items.len < 2) return false;

        const config = switch (items[1]) {
            .object => |object| object,
            else => return error.UnsupportedRuleConfigValue,
        };
        const option = config.get("enforceForInnerExpressions") orelse config.get("enforceForLogicalOperands") orelse return false;
        return switch (option) {
            .bool => |enabled| enabled,
            else => return error.UnsupportedRuleConfigValue,
        };
    }

    fn noFallthroughAllowEmptyCaseFromConfig(value: std.json.Value) RuleConfigError!NoFallthroughAllowEmptyCase {
        const allow = try noFallthroughBoolOptionFromConfig(value, "allowEmptyCase", false);
        return if (allow) .yes else .no;
    }

    fn noFallthroughReportUnusedFallthroughCommentFromConfig(value: std.json.Value) RuleConfigError!bool {
        return noFallthroughBoolOptionFromConfig(value, "reportUnusedFallthroughComment", false);
    }

    fn noFallthroughCommentPatternFromConfig(value: std.json.Value) RuleConfigError!NoFallthroughCommentPattern {
        const items = switch (value) {
            .array => |array| array.items,
            else => return .{},
        };
        if (items.len < 2) return .{};

        const config = switch (items[1]) {
            .object => |object| object,
            else => return error.UnsupportedRuleConfigValue,
        };
        const pattern_value = switch (config.get("commentPattern") orelse return .{}) {
            .string => |pattern_value| pattern_value,
            else => return error.UnsupportedRuleConfigValue,
        };

        var pattern = NoFallthroughCommentPattern{};
        pattern.set(pattern_value) catch return error.UnsupportedRuleConfigValue;
        return pattern;
    }

    fn noFallthroughBoolOptionFromConfig(value: std.json.Value, key: []const u8, default: bool) RuleConfigError!bool {
        const items = switch (value) {
            .array => |array| array.items,
            else => return default,
        };
        if (items.len < 2) return default;

        const config = switch (items[1]) {
            .object => |object| object,
            else => return error.UnsupportedRuleConfigValue,
        };
        return switch (config.get(key) orelse return default) {
            .bool => |enabled| enabled,
            else => return error.UnsupportedRuleConfigValue,
        };
    }

    fn importNewlineAfterImportCountFromConfig(value: std.json.Value) RuleConfigError!usize {
        const items = switch (value) {
            .array => |array| array.items,
            else => return 1,
        };
        if (items.len < 2) return 1;

        const config = switch (items[1]) {
            .object => |object| object,
            else => return error.UnsupportedRuleConfigValue,
        };
        const count = switch (config.get("count") orelse return 1) {
            .integer => |count| count,
            else => return error.UnsupportedRuleConfigValue,
        };
        if (count < 0) return error.UnsupportedRuleConfigValue;
        return @intCast(count);
    }

    fn importNewlineAfterImportExactCountFromConfig(value: std.json.Value) RuleConfigError!bool {
        const items = switch (value) {
            .array => |array| array.items,
            else => return false,
        };
        if (items.len < 2) return false;

        const config = switch (items[1]) {
            .object => |object| object,
            else => return error.UnsupportedRuleConfigValue,
        };
        return switch (config.get("exactCount") orelse return false) {
            .bool => |enabled| enabled,
            else => return error.UnsupportedRuleConfigValue,
        };
    }

    fn noImplicitCoercionBooleanFromConfig(value: std.json.Value) RuleConfigError!NoImplicitCoercionBoolean {
        const enabled = try noImplicitCoercionOptionFromConfig(value, "boolean");
        return if (enabled) .yes else .no;
    }

    fn noImplicitCoercionNumberFromConfig(value: std.json.Value) RuleConfigError!NoImplicitCoercionNumber {
        const enabled = try noImplicitCoercionOptionFromConfig(value, "number");
        return if (enabled) .yes else .no;
    }

    fn noImplicitCoercionStringFromConfig(value: std.json.Value) RuleConfigError!NoImplicitCoercionString {
        const enabled = try noImplicitCoercionOptionFromConfig(value, "string");
        return if (enabled) .yes else .no;
    }

    fn noImplicitCoercionDisallowTemplateShorthandFromConfig(value: std.json.Value) RuleConfigError!bool {
        const items = switch (value) {
            .array => |array| array.items,
            else => return false,
        };
        if (items.len < 2) return false;

        const config = switch (items[1]) {
            .object => |object| object,
            else => return error.UnsupportedRuleConfigValue,
        };
        return switch (config.get("disallowTemplateShorthand") orelse return false) {
            .bool => |enabled| enabled,
            else => error.UnsupportedRuleConfigValue,
        };
    }

    fn noImplicitCoercionOptionFromConfig(value: std.json.Value, key: []const u8) RuleConfigError!bool {
        const items = switch (value) {
            .array => |array| array.items,
            else => return true,
        };
        if (items.len < 2) return true;

        const config = switch (items[1]) {
            .object => |object| object,
            else => return error.UnsupportedRuleConfigValue,
        };
        return switch (config.get(key) orelse return true) {
            .bool => |enabled| enabled,
            else => error.UnsupportedRuleConfigValue,
        };
    }

    fn noImplicitCoercionAllowFromConfig(value: std.json.Value, expected: []const u8) RuleConfigError!bool {
        const items = switch (value) {
            .array => |array| array.items,
            else => return false,
        };
        if (items.len < 2) return false;

        const config = switch (items[1]) {
            .object => |object| object,
            else => return error.UnsupportedRuleConfigValue,
        };
        const allow_value = config.get("allow") orelse return false;
        const allow_items = switch (allow_value) {
            .array => |array| array.items,
            else => return error.UnsupportedRuleConfigValue,
        };

        var found = false;
        for (allow_items) |item| {
            const allow = switch (item) {
                .string => |allow| allow,
                else => return error.UnsupportedRuleConfigValue,
            };
            if (!isNoImplicitCoercionAllowToken(allow)) return error.UnsupportedRuleConfigValue;
            if (std.mem.eql(u8, allow, expected)) found = true;
        }
        return found;
    }

    fn isNoImplicitCoercionAllowToken(value: []const u8) bool {
        return std.mem.eql(u8, value, "!!") or
            std.mem.eql(u8, value, "~") or
            std.mem.eql(u8, value, "+") or
            std.mem.eql(u8, value, "*") or
            std.mem.eql(u8, value, "-") or
            std.mem.eql(u8, value, "- -");
    }

    fn noInnerDeclarationsModeFromConfig(value: std.json.Value) RuleConfigError!NoInnerDeclarationsMode {
        const items = switch (value) {
            .array => |array| array.items,
            else => return .functions,
        };
        if (items.len < 2) return .functions;

        const mode = switch (items[1]) {
            .string => |mode| mode,
            else => return error.UnsupportedRuleConfigValue,
        };
        if (std.mem.eql(u8, mode, "functions")) return .functions;
        if (std.mem.eql(u8, mode, "both")) return .both;
        return error.UnsupportedRuleConfigValue;
    }

    fn noLabelsAllowLoopFromConfig(value: std.json.Value) RuleConfigError!NoLabelsAllowLoop {
        const enabled = try noLabelsBoolOptionFromConfig(value, "allowLoop", false);
        return if (enabled) .yes else .no;
    }

    fn noLabelsAllowSwitchFromConfig(value: std.json.Value) RuleConfigError!NoLabelsAllowSwitch {
        const enabled = try noLabelsBoolOptionFromConfig(value, "allowSwitch", false);
        return if (enabled) .yes else .no;
    }

    fn noLabelsBoolOptionFromConfig(value: std.json.Value, key: []const u8, default: bool) RuleConfigError!bool {
        const items = switch (value) {
            .array => |array| array.items,
            else => return default,
        };
        if (items.len < 2) return default;

        const config = switch (items[1]) {
            .object => |object| object,
            else => return error.UnsupportedRuleConfigValue,
        };
        return switch (config.get(key) orelse return default) {
            .bool => |enabled| enabled,
            else => error.UnsupportedRuleConfigValue,
        };
    }

    fn noDuplicateImportsBoolOptionFromConfig(value: std.json.Value, key: []const u8, default: bool) RuleConfigError!bool {
        const items = switch (value) {
            .array => |array| array.items,
            else => return default,
        };
        if (items.len < 2) return default;

        const config = switch (items[1]) {
            .object => |object| object,
            else => return error.UnsupportedRuleConfigValue,
        };
        return switch (config.get(key) orelse return default) {
            .bool => |enabled| enabled,
            else => error.UnsupportedRuleConfigValue,
        };
    }

    fn noMixedSpacesAndTabsSmartTabsFromConfig(value: std.json.Value) RuleConfigError!bool {
        const items = switch (value) {
            .array => |array| array.items,
            else => return false,
        };
        if (items.len < 2) return false;

        const style = switch (items[1]) {
            .string => |style| style,
            else => return error.UnsupportedRuleConfigValue,
        };
        if (std.mem.eql(u8, style, "smart-tabs")) return true;
        return error.UnsupportedRuleConfigValue;
    }

    fn noMultiSpacesIgnoreEOLCommentsFromConfig(value: std.json.Value) RuleConfigError!NoMultiSpacesIgnoreEOLComments {
        const items = switch (value) {
            .array => |array| array.items,
            else => return .no,
        };
        if (items.len < 2) return .no;

        const config = switch (items[1]) {
            .object => |object| object,
            else => return error.UnsupportedRuleConfigValue,
        };
        const ignore = switch (config.get("ignoreEOLComments") orelse return .no) {
            .bool => |enabled| enabled,
            else => return error.UnsupportedRuleConfigValue,
        };
        return if (ignore) .yes else .no;
    }

    fn noMultiSpacesExceptionsFromConfig(value: std.json.Value) RuleConfigError!NoMultiSpacesExceptions {
        const items = switch (value) {
            .array => |array| array.items,
            else => return .{},
        };
        if (items.len < 2) return .{};

        const config = switch (items[1]) {
            .object => |object| object,
            else => return error.UnsupportedRuleConfigValue,
        };
        const exceptions = switch (config.get("exceptions") orelse return .{}) {
            .object => |exceptions| exceptions,
            else => return error.UnsupportedRuleConfigValue,
        };

        var options = NoMultiSpacesExceptions{};
        if (exceptions.get("Property")) |entry| options.property = try noMultiSpacesExceptionEnabled(entry);
        if (exceptions.get("BinaryExpression")) |entry| options.binary_expression = try noMultiSpacesExceptionEnabled(entry);
        if (exceptions.get("VariableDeclarator")) |entry| options.variable_declarator = try noMultiSpacesExceptionEnabled(entry);
        if (exceptions.get("ImportDeclaration")) |entry| options.import_declaration = try noMultiSpacesExceptionEnabled(entry);
        return options;
    }

    fn noMultiSpacesExceptionEnabled(value: std.json.Value) RuleConfigError!bool {
        return switch (value) {
            .bool => |enabled| enabled,
            else => error.UnsupportedRuleConfigValue,
        };
    }

    fn noMultipleEmptyLinesMaxFromConfig(value: std.json.Value) RuleConfigError!usize {
        const items = switch (value) {
            .array => |array| array.items,
            else => return 2,
        };
        if (items.len < 2) return 2;

        const config = switch (items[1]) {
            .object => |object| object,
            else => return error.UnsupportedRuleConfigValue,
        };
        const max = switch (config.get("max") orelse return 2) {
            .integer => |max| max,
            else => return error.UnsupportedRuleConfigValue,
        };
        if (max < 0) return error.UnsupportedRuleConfigValue;
        return @intCast(max);
    }

    fn noMultipleEmptyLinesMaxBofFromConfig(value: std.json.Value) RuleConfigError!?usize {
        const items = switch (value) {
            .array => |array| array.items,
            else => return null,
        };
        if (items.len < 2) return null;

        const config = switch (items[1]) {
            .object => |object| object,
            else => return error.UnsupportedRuleConfigValue,
        };
        const max = switch (config.get("maxBOF") orelse return null) {
            .integer => |max| max,
            else => return error.UnsupportedRuleConfigValue,
        };
        if (max < 0) return error.UnsupportedRuleConfigValue;
        return @intCast(max);
    }

    fn noMultipleEmptyLinesMaxEofFromConfig(value: std.json.Value) RuleConfigError!?usize {
        const items = switch (value) {
            .array => |array| array.items,
            else => return null,
        };
        if (items.len < 2) return null;

        const config = switch (items[1]) {
            .object => |object| object,
            else => return error.UnsupportedRuleConfigValue,
        };
        const max = switch (config.get("maxEOF") orelse return null) {
            .integer => |max| max,
            else => return error.UnsupportedRuleConfigValue,
        };
        if (max < 0) return error.UnsupportedRuleConfigValue;
        return @intCast(max);
    }

    fn noParamReassignPropsFromConfig(value: std.json.Value) RuleConfigError!NoParamReassignProps {
        const items = switch (value) {
            .array => |array| array.items,
            else => return .no,
        };
        if (items.len < 2) return .no;

        const config = switch (items[1]) {
            .object => |object| object,
            else => return error.UnsupportedRuleConfigValue,
        };
        const props = switch (config.get("props") orelse return .no) {
            .bool => |enabled| enabled,
            else => return error.UnsupportedRuleConfigValue,
        };
        return if (props) .yes else .no;
    }

    fn noParamReassignIgnoredNamesFromConfig(value: std.json.Value) RuleConfigError!NoParamReassignIgnoredNames {
        const items = switch (value) {
            .array => |array| array.items,
            else => return .{},
        };
        if (items.len < 2) return .{};

        const config = switch (items[1]) {
            .object => |object| object,
            else => return error.UnsupportedRuleConfigValue,
        };
        const ignored_value = config.get("ignorePropertyModificationsFor") orelse return .{};
        const ignored_items = switch (ignored_value) {
            .array => |array| array.items,
            else => return error.UnsupportedRuleConfigValue,
        };

        var ignored = NoParamReassignIgnoredNames{};
        for (ignored_items) |item| {
            const name = switch (item) {
                .string => |name| name,
                else => return error.UnsupportedRuleConfigValue,
            };
            ignored.append(name) catch return error.UnsupportedRuleConfigValue;
        }
        return ignored;
    }

    fn noParamReassignIgnoredNamePatternsFromConfig(value: std.json.Value) RuleConfigError!NoParamReassignIgnoredNamePatterns {
        const items = switch (value) {
            .array => |array| array.items,
            else => return .{},
        };
        if (items.len < 2) return .{};

        const config = switch (items[1]) {
            .object => |object| object,
            else => return error.UnsupportedRuleConfigValue,
        };
        const ignored_value = config.get("ignorePropertyModificationsForRegex") orelse return .{};
        const ignored_items = switch (ignored_value) {
            .array => |array| array.items,
            else => return error.UnsupportedRuleConfigValue,
        };

        var ignored = NoParamReassignIgnoredNamePatterns{};
        for (ignored_items) |item| {
            const pattern = switch (item) {
                .string => |pattern| pattern,
                else => return error.UnsupportedRuleConfigValue,
            };
            ignored.append(pattern) catch return error.UnsupportedRuleConfigValue;
        }
        return ignored;
    }

    fn noShadowAllowFromConfig(value: std.json.Value) RuleConfigError!NoShadowAllowNames {
        const items = switch (value) {
            .array => |array| array.items,
            else => return .{},
        };
        if (items.len < 2) return .{};

        const config = switch (items[1]) {
            .object => |object| object,
            else => return error.UnsupportedRuleConfigValue,
        };
        const allow_value = config.get("allow") orelse return .{};
        const allow_items = switch (allow_value) {
            .array => |array| array.items,
            else => return error.UnsupportedRuleConfigValue,
        };

        var allow = NoShadowAllowNames{};
        for (allow_items) |item| {
            const name = switch (item) {
                .string => |name| name,
                else => return error.UnsupportedRuleConfigValue,
            };
            allow.append(name) catch return error.UnsupportedRuleConfigValue;
        }
        return allow;
    }

    fn noShadowBuiltinGlobalsFromConfig(value: std.json.Value) RuleConfigError!bool {
        const items = switch (value) {
            .array => |array| array.items,
            else => return false,
        };
        if (items.len < 2) return false;

        const config = switch (items[1]) {
            .object => |object| object,
            else => return error.UnsupportedRuleConfigValue,
        };
        return switch (config.get("builtinGlobals") orelse return false) {
            .bool => |enabled| enabled,
            else => return error.UnsupportedRuleConfigValue,
        };
    }

    fn noShadowHoistFromConfig(value: std.json.Value, default: NoShadowHoist) RuleConfigError!NoShadowHoist {
        const items = switch (value) {
            .array => |array| array.items,
            else => return default,
        };
        if (items.len < 2) return default;

        const config = switch (items[1]) {
            .object => |object| object,
            else => return error.UnsupportedRuleConfigValue,
        };
        const hoist = switch (config.get("hoist") orelse return default) {
            .string => |hoist| hoist,
            else => return error.UnsupportedRuleConfigValue,
        };

        if (std.mem.eql(u8, hoist, "all")) return .all;
        if (std.mem.eql(u8, hoist, "functions")) return .functions;
        if (std.mem.eql(u8, hoist, "functions-and-types")) return .functions_and_types;
        if (std.mem.eql(u8, hoist, "never")) return .never;
        if (std.mem.eql(u8, hoist, "types")) return .types;
        return error.UnsupportedRuleConfigValue;
    }

    fn noShadowBoolOptionFromConfig(value: std.json.Value, key: []const u8, default: bool) RuleConfigError!bool {
        const items = switch (value) {
            .array => |array| array.items,
            else => return default,
        };
        if (items.len < 2) return default;

        const config = switch (items[1]) {
            .object => |object| object,
            else => return error.UnsupportedRuleConfigValue,
        };
        return switch (config.get(key) orelse return default) {
            .bool => |enabled| enabled,
            else => return error.UnsupportedRuleConfigValue,
        };
    }

    fn noUnderscoreDangleBoolOptionFromConfig(value: std.json.Value, key: []const u8, default: bool) RuleConfigError!bool {
        const items = switch (value) {
            .array => |array| array.items,
            else => return default,
        };
        if (items.len < 2) return default;

        const config = switch (items[1]) {
            .object => |object| object,
            else => return error.UnsupportedRuleConfigValue,
        };
        return switch (config.get(key) orelse return default) {
            .bool => |enabled| enabled,
            else => return error.UnsupportedRuleConfigValue,
        };
    }

    fn noUnderscoreDangleAllowFromConfig(value: std.json.Value) RuleConfigError!NoShadowAllowNames {
        const items = switch (value) {
            .array => |array| array.items,
            else => return .{},
        };
        if (items.len < 2) return .{};

        const config = switch (items[1]) {
            .object => |object| object,
            else => return error.UnsupportedRuleConfigValue,
        };
        const allow_value = config.get("allow") orelse return .{};
        const allow_items = switch (allow_value) {
            .array => |array| array.items,
            else => return error.UnsupportedRuleConfigValue,
        };

        var allow = NoShadowAllowNames{};
        for (allow_items) |item| {
            const name = switch (item) {
                .string => |name| name,
                else => return error.UnsupportedRuleConfigValue,
            };
            allow.append(name) catch return error.UnsupportedRuleConfigValue;
        }
        return allow;
    }

    fn noPlusplusAllowForLoopAfterthoughtsFromConfig(value: std.json.Value) RuleConfigError!NoPlusplusAllowForLoopAfterthoughts {
        const items = switch (value) {
            .array => |array| array.items,
            else => return .no,
        };
        if (items.len < 2) return .no;

        const config = switch (items[1]) {
            .object => |object| object,
            else => return error.UnsupportedRuleConfigValue,
        };
        const allow = switch (config.get("allowForLoopAfterthoughts") orelse return .no) {
            .bool => |enabled| enabled,
            else => return error.UnsupportedRuleConfigValue,
        };
        return if (allow) .yes else .no;
    }

    fn noRedeclareBuiltinGlobalsFromConfig(value: std.json.Value) RuleConfigError!NoRedeclareBuiltinGlobals {
        const items = switch (value) {
            .array => |array| array.items,
            else => return .no,
        };
        if (items.len < 2) return .no;

        const config = switch (items[1]) {
            .object => |object| object,
            else => return error.UnsupportedRuleConfigValue,
        };
        const enabled = switch (config.get("builtinGlobals") orelse return .no) {
            .bool => |bool_value| bool_value,
            else => return error.UnsupportedRuleConfigValue,
        };
        return if (enabled) .yes else .no;
    }

    fn preferConstDestructuringFromConfig(value: std.json.Value) RuleConfigError!PreferConstDestructuring {
        const items = switch (value) {
            .array => |array| array.items,
            else => return .any,
        };
        if (items.len < 2) return .any;

        const config = switch (items[1]) {
            .object => |object| object,
            else => return error.UnsupportedRuleConfigValue,
        };
        const destructuring = switch (config.get("destructuring") orelse return .any) {
            .string => |destructuring| destructuring,
            else => return error.UnsupportedRuleConfigValue,
        };
        if (std.mem.eql(u8, destructuring, "any")) return .any;
        if (std.mem.eql(u8, destructuring, "all")) return .all;
        return error.UnsupportedRuleConfigValue;
    }

    fn preferConstBoolOptionFromConfig(value: std.json.Value, key: []const u8, default: bool) RuleConfigError!bool {
        const items = switch (value) {
            .array => |array| array.items,
            else => return default,
        };
        if (items.len < 2) return default;

        const config = switch (items[1]) {
            .object => |object| object,
            else => return error.UnsupportedRuleConfigValue,
        };
        const option = config.get(key) orelse return default;
        return switch (option) {
            .bool => |enabled| enabled,
            else => error.UnsupportedRuleConfigValue,
        };
    }

    fn requireAtomicUpdatesBoolOptionFromConfig(value: std.json.Value, key: []const u8, default: bool) RuleConfigError!bool {
        const items = switch (value) {
            .array => |array| array.items,
            else => return default,
        };
        if (items.len < 2) return default;

        const config = switch (items[1]) {
            .object => |object| object,
            else => return error.UnsupportedRuleConfigValue,
        };
        return switch (config.get(key) orelse return default) {
            .bool => |enabled| enabled,
            else => error.UnsupportedRuleConfigValue,
        };
    }

    fn preferDestructuringOptionFromConfig(
        value: std.json.Value,
        node_key: []const u8,
        kind_key: []const u8,
        default: bool,
    ) RuleConfigError!bool {
        const items = switch (value) {
            .array => |array| array.items,
            else => return default,
        };
        if (items.len < 2) return default;

        const config = switch (items[1]) {
            .object => |object| object,
            else => return error.UnsupportedRuleConfigValue,
        };
        if (config.get(node_key)) |node_config_value| {
            const node_config = switch (node_config_value) {
                .object => |object| object,
                else => return error.UnsupportedRuleConfigValue,
            };
            return switch (node_config.get(kind_key) orelse return default) {
                .bool => |enabled| enabled,
                else => error.UnsupportedRuleConfigValue,
            };
        }
        return switch (config.get(kind_key) orelse return default) {
            .bool => |enabled| enabled,
            else => error.UnsupportedRuleConfigValue,
        };
    }

    fn preferDestructuringEnforceForRenamedPropertiesFromConfig(value: std.json.Value) RuleConfigError!bool {
        const items = switch (value) {
            .array => |array| array.items,
            else => return false,
        };
        if (items.len < 3) return false;

        const config = switch (items[2]) {
            .object => |object| object,
            else => return error.UnsupportedRuleConfigValue,
        };
        return switch (config.get("enforceForRenamedProperties") orelse return false) {
            .bool => |enabled| enabled,
            else => error.UnsupportedRuleConfigValue,
        };
    }

    fn preferPromiseRejectErrorsAllowEmptyRejectFromConfig(value: std.json.Value) RuleConfigError!bool {
        const items = switch (value) {
            .array => |array| array.items,
            else => return false,
        };
        if (items.len < 2) return false;

        const config = switch (items[1]) {
            .object => |object| object,
            else => return error.UnsupportedRuleConfigValue,
        };
        return switch (config.get("allowEmptyReject") orelse return false) {
            .bool => |enabled| enabled,
            else => error.UnsupportedRuleConfigValue,
        };
    }

    fn noPromiseExecutorReturnAllowVoidFromConfig(value: std.json.Value) RuleConfigError!bool {
        const items = switch (value) {
            .array => |array| array.items,
            else => return false,
        };
        if (items.len < 2) return false;

        const config = switch (items[1]) {
            .object => |object| object,
            else => return error.UnsupportedRuleConfigValue,
        };
        return switch (config.get("allowVoid") orelse return false) {
            .bool => |enabled| enabled,
            else => error.UnsupportedRuleConfigValue,
        };
    }

    fn preferRegexLiteralsDisallowRedundantWrappingFromConfig(value: std.json.Value) RuleConfigError!bool {
        const items = switch (value) {
            .array => |array| array.items,
            else => return false,
        };
        if (items.len < 2) return false;

        const config = switch (items[1]) {
            .object => |object| object,
            else => return error.UnsupportedRuleConfigValue,
        };
        return switch (config.get("disallowRedundantWrapping") orelse return false) {
            .bool => |enabled| enabled,
            else => error.UnsupportedRuleConfigValue,
        };
    }

    fn noReturnAssignStyleFromConfig(value: std.json.Value) RuleConfigError!NoReturnAssignStyle {
        const items = switch (value) {
            .array => |array| array.items,
            else => return .except_parens,
        };
        if (items.len < 2) return .except_parens;

        const style = switch (items[1]) {
            .string => |style| style,
            else => return error.UnsupportedRuleConfigValue,
        };
        if (std.mem.eql(u8, style, "except-parens")) return .except_parens;
        if (std.mem.eql(u8, style, "always")) return .always;
        return error.UnsupportedRuleConfigValue;
    }

    fn radixStyleFromConfig(value: std.json.Value) RuleConfigError!RadixStyle {
        const items = switch (value) {
            .array => |array| array.items,
            else => return .always,
        };
        if (items.len < 2) return .always;

        const style = switch (items[1]) {
            .string => |style| style,
            else => return error.UnsupportedRuleConfigValue,
        };
        if (std.mem.eql(u8, style, "always")) return .always;
        if (std.mem.eql(u8, style, "as-needed")) return .as_needed;
        return error.UnsupportedRuleConfigValue;
    }

    fn noSequencesAllowInParenthesesFromConfig(value: std.json.Value) RuleConfigError!NoSequencesAllowInParentheses {
        const items = switch (value) {
            .array => |array| array.items,
            else => return .yes,
        };
        if (items.len < 2) return .yes;

        const config = switch (items[1]) {
            .object => |object| object,
            else => return error.UnsupportedRuleConfigValue,
        };
        const allow = switch (config.get("allowInParentheses") orelse return .yes) {
            .bool => |enabled| enabled,
            else => return error.UnsupportedRuleConfigValue,
        };
        return if (allow) .yes else .no;
    }

    fn noUselessComputedKeyEnforceForClassMembersFromConfig(value: std.json.Value) RuleConfigError!NoUselessComputedKeyEnforceForClassMembers {
        const items = switch (value) {
            .array => |array| array.items,
            else => return .yes,
        };
        if (items.len < 2) return .yes;

        const config = switch (items[1]) {
            .object => |object| object,
            else => return error.UnsupportedRuleConfigValue,
        };
        const enforce = switch (config.get("enforceForClassMembers") orelse return .yes) {
            .bool => |enabled| enabled,
            else => return error.UnsupportedRuleConfigValue,
        };
        return if (enforce) .yes else .no;
    }

    fn noUnusedExpressionsAllowShortCircuitFromConfig(value: std.json.Value) RuleConfigError!NoUnusedExpressionsAllowShortCircuit {
        const items = switch (value) {
            .array => |array| array.items,
            else => return .no,
        };
        if (items.len < 2) return .no;

        const config = switch (items[1]) {
            .object => |object| object,
            else => return error.UnsupportedRuleConfigValue,
        };
        const allow = switch (config.get("allowShortCircuit") orelse return .no) {
            .bool => |enabled| enabled,
            else => return error.UnsupportedRuleConfigValue,
        };
        return if (allow) .yes else .no;
    }

    fn noUnusedExpressionsAllowTernaryFromConfig(value: std.json.Value) RuleConfigError!NoUnusedExpressionsAllowTernary {
        const items = switch (value) {
            .array => |array| array.items,
            else => return .no,
        };
        if (items.len < 2) return .no;

        const config = switch (items[1]) {
            .object => |object| object,
            else => return error.UnsupportedRuleConfigValue,
        };
        const allow = switch (config.get("allowTernary") orelse return .no) {
            .bool => |enabled| enabled,
            else => return error.UnsupportedRuleConfigValue,
        };
        return if (allow) .yes else .no;
    }

    fn noUnusedExpressionsAllowTaggedTemplatesFromConfig(value: std.json.Value) RuleConfigError!NoUnusedExpressionsAllowTaggedTemplates {
        const items = switch (value) {
            .array => |array| array.items,
            else => return .no,
        };
        if (items.len < 2) return .no;

        const config = switch (items[1]) {
            .object => |object| object,
            else => return error.UnsupportedRuleConfigValue,
        };
        const allow = switch (config.get("allowTaggedTemplates") orelse return .no) {
            .bool => |enabled| enabled,
            else => return error.UnsupportedRuleConfigValue,
        };
        return if (allow) .yes else .no;
    }

    fn noUnusedVarsArgsFromConfig(value: std.json.Value, default: NoUnusedVarsArgs) RuleConfigError!NoUnusedVarsArgs {
        const items = switch (value) {
            .array => |array| array.items,
            else => return default,
        };
        if (items.len < 2) return default;

        const config = switch (items[1]) {
            .object => |object| object,
            else => return error.UnsupportedRuleConfigValue,
        };
        const args = switch (config.get("args") orelse return default) {
            .string => |args| args,
            else => return error.UnsupportedRuleConfigValue,
        };
        if (std.mem.eql(u8, args, "none")) return .none;
        if (std.mem.eql(u8, args, "after-used")) return .after_used;
        if (std.mem.eql(u8, args, "all")) return .all;
        return error.UnsupportedRuleConfigValue;
    }

    fn noUnusedVarsVarsFromConfig(value: std.json.Value, default: NoUnusedVarsVars) RuleConfigError!NoUnusedVarsVars {
        const items = switch (value) {
            .array => |array| array.items,
            else => return default,
        };
        if (items.len < 2) return default;

        const config = switch (items[1]) {
            .object => |object| object,
            else => return error.UnsupportedRuleConfigValue,
        };
        const vars = switch (config.get("vars") orelse return default) {
            .string => |vars| vars,
            else => return error.UnsupportedRuleConfigValue,
        };
        if (std.mem.eql(u8, vars, "all")) return .all;
        if (std.mem.eql(u8, vars, "local")) return .local;
        return error.UnsupportedRuleConfigValue;
    }

    fn noUnusedVarsCaughtErrorsFromConfig(value: std.json.Value, default: NoUnusedVarsCaughtErrors) RuleConfigError!NoUnusedVarsCaughtErrors {
        const items = switch (value) {
            .array => |array| array.items,
            else => return default,
        };
        if (items.len < 2) return default;

        const config = switch (items[1]) {
            .object => |object| object,
            else => return error.UnsupportedRuleConfigValue,
        };
        const caught_errors = switch (config.get("caughtErrors") orelse return default) {
            .string => |caught_errors| caught_errors,
            else => return error.UnsupportedRuleConfigValue,
        };
        if (std.mem.eql(u8, caught_errors, "none")) return .none;
        if (std.mem.eql(u8, caught_errors, "all")) return .all;
        return error.UnsupportedRuleConfigValue;
    }

    fn noUnusedVarsIgnoreRestSiblingsFromConfig(value: std.json.Value, default: bool) RuleConfigError!bool {
        return noUnusedVarsBoolOptionFromConfig(value, "ignoreRestSiblings", default);
    }

    fn noUnusedVarsReportUsedIgnorePatternFromConfig(value: std.json.Value, default: bool) RuleConfigError!bool {
        return noUnusedVarsBoolOptionFromConfig(value, "reportUsedIgnorePattern", default);
    }

    fn noUnusedVarsBoolOptionFromConfig(value: std.json.Value, key: []const u8, default: bool) RuleConfigError!bool {
        const items = switch (value) {
            .array => |array| array.items,
            else => return default,
        };
        if (items.len < 2) return default;

        const config = switch (items[1]) {
            .object => |object| object,
            else => return error.UnsupportedRuleConfigValue,
        };
        return switch (config.get(key) orelse return default) {
            .bool => |enabled| enabled,
            else => return error.UnsupportedRuleConfigValue,
        };
    }

    fn noUnusedVarsIgnorePatternFromConfig(value: std.json.Value, key: []const u8) RuleConfigError!NoUnusedVarsIgnorePattern {
        const items = switch (value) {
            .array => |array| array.items,
            else => return .{},
        };
        if (items.len < 2) return .{};

        const config = switch (items[1]) {
            .object => |object| object,
            else => return error.UnsupportedRuleConfigValue,
        };
        const pattern_value = switch (config.get(key) orelse return .{}) {
            .string => |pattern_value| pattern_value,
            else => return error.UnsupportedRuleConfigValue,
        };
        if (pattern_value.len == 0) return .{};

        var pattern = NoUnusedVarsIgnorePattern{};
        pattern.set(pattern_value) catch return error.UnsupportedRuleConfigValue;
        return pattern;
    }

    fn noUseBeforeDefineCheckFromConfig(value: std.json.Value, key: []const u8, default: bool) RuleConfigError!NoUseBeforeDefineCheck {
        const items = switch (value) {
            .array => |array| array.items,
            else => return if (default) .yes else .no,
        };
        if (items.len < 2) return if (default) .yes else .no;

        const config = switch (items[1]) {
            .string => |style| {
                if (std.mem.eql(u8, style, "nofunc")) {
                    return if (std.mem.eql(u8, key, "functions")) .no else if (default) .yes else .no;
                }
                return error.UnsupportedRuleConfigValue;
            },
            .object => |object| object,
            else => return error.UnsupportedRuleConfigValue,
        };
        const enabled = switch (config.get(key) orelse return if (default) .yes else .no) {
            .bool => |enabled| enabled,
            else => return error.UnsupportedRuleConfigValue,
        };
        return if (enabled) .yes else .no;
    }

    fn noUseBeforeDefineAllowNamedExportsFromConfig(value: std.json.Value) RuleConfigError!bool {
        return noUseBeforeDefineBoolOptionFromConfig(value, "allowNamedExports", false);
    }

    fn noUseBeforeDefineBoolOptionFromConfig(value: std.json.Value, key: []const u8, default: bool) RuleConfigError!bool {
        const items = switch (value) {
            .array => |array| array.items,
            else => return default,
        };
        if (items.len < 2) return default;

        const config = switch (items[1]) {
            .object => |object| object,
            .string => return default,
            else => return error.UnsupportedRuleConfigValue,
        };
        return switch (config.get(key) orelse return default) {
            .bool => |enabled| enabled,
            else => return error.UnsupportedRuleConfigValue,
        };
    }

    fn objectShorthandStyleFromConfig(value: std.json.Value) RuleConfigError!ObjectShorthandStyle {
        const items = switch (value) {
            .array => |array| array.items,
            else => return .always,
        };
        if (items.len < 2) return .always;

        const style = switch (items[1]) {
            .string => |style| style,
            .object => return .always,
            else => return error.UnsupportedRuleConfigValue,
        };
        if (std.mem.eql(u8, style, "always")) return .always;
        if (std.mem.eql(u8, style, "methods")) return .methods;
        if (std.mem.eql(u8, style, "properties")) return .properties;
        if (std.mem.eql(u8, style, "never")) return .never;
        return error.UnsupportedRuleConfigValue;
    }

    fn objectShorthandAvoidQuotesFromConfig(value: std.json.Value) RuleConfigError!bool {
        return objectShorthandBoolOptionFromConfig(value, "avoidQuotes");
    }

    fn objectShorthandIgnoreConstructorsFromConfig(value: std.json.Value) RuleConfigError!bool {
        return objectShorthandBoolOptionFromConfig(value, "ignoreConstructors");
    }

    fn objectShorthandAvoidExplicitReturnArrowsFromConfig(value: std.json.Value) RuleConfigError!bool {
        return objectShorthandBoolOptionFromConfig(value, "avoidExplicitReturnArrows");
    }

    fn objectShorthandBoolOptionFromConfig(value: std.json.Value, key: []const u8) RuleConfigError!bool {
        const items = switch (value) {
            .array => |array| array.items,
            else => return false,
        };
        if (items.len < 2) return false;

        const config_value = switch (items[1]) {
            .object => items[1],
            .string => if (items.len >= 3) items[2] else return false,
            else => return error.UnsupportedRuleConfigValue,
        };
        const config = switch (config_value) {
            .object => |object| object,
            else => return error.UnsupportedRuleConfigValue,
        };
        return switch (config.get(key) orelse return false) {
            .bool => |enabled| enabled,
            else => error.UnsupportedRuleConfigValue,
        };
    }

    const OneVarNeverConfig = struct {
        @"var": bool = true,
        let: bool = true,
        @"const": bool = true,
    };

    fn oneVarNeverConfigFromConfig(value: std.json.Value) RuleConfigError!OneVarNeverConfig {
        const items = switch (value) {
            .array => |array| array.items,
            else => return .{},
        };
        if (items.len < 2) return .{};

        return switch (items[1]) {
            .string => |style| {
                if (!std.mem.eql(u8, style, "never")) return error.UnsupportedRuleConfigValue;
                return .{};
            },
            .object => |object| oneVarNeverObjectConfig(object),
            else => error.UnsupportedRuleConfigValue,
        };
    }

    fn oneVarNeverObjectConfig(object: std.json.ObjectMap) RuleConfigError!OneVarNeverConfig {
        var config = OneVarNeverConfig{
            .@"var" = false,
            .let = false,
            .@"const" = false,
        };
        var matched = false;

        if (object.get("var")) |value| {
            config.@"var" = try oneVarNeverOption(value);
            matched = true;
        }
        if (object.get("let")) |value| {
            config.let = try oneVarNeverOption(value);
            matched = true;
        }
        if (object.get("const")) |value| {
            config.@"const" = try oneVarNeverOption(value);
            matched = true;
        }

        if (!matched) return error.UnsupportedRuleConfigValue;
        return config;
    }

    fn oneVarNeverOption(value: std.json.Value) RuleConfigError!bool {
        const style = switch (value) {
            .string => |style| style,
            else => return error.UnsupportedRuleConfigValue,
        };
        if (!std.mem.eql(u8, style, "never")) return error.UnsupportedRuleConfigValue;
        return true;
    }

    fn operatorAssignmentStyleFromConfig(value: std.json.Value) RuleConfigError!OperatorAssignmentStyle {
        const items = switch (value) {
            .array => |array| array.items,
            else => return .always,
        };
        if (items.len < 2) return .always;

        const style = switch (items[1]) {
            .string => |style| style,
            else => return error.UnsupportedRuleConfigValue,
        };
        if (std.mem.eql(u8, style, "always")) return .always;
        if (std.mem.eql(u8, style, "never")) return .never;
        return error.UnsupportedRuleConfigValue;
    }

    fn noUndefTypeofFromConfig(value: std.json.Value) RuleConfigError!bool {
        const items = switch (value) {
            .array => |array| array.items,
            else => return false,
        };
        if (items.len < 2) return false;

        const config = switch (items[1]) {
            .object => |object| object,
            else => return error.UnsupportedRuleConfigValue,
        };
        return switch (config.get("typeof") orelse return false) {
            .bool => |enabled| enabled,
            else => return error.UnsupportedRuleConfigValue,
        };
    }

    fn noTabsAllowIndentationTabsFromConfig(value: std.json.Value) RuleConfigError!bool {
        const items = switch (value) {
            .array => |array| array.items,
            else => return false,
        };
        if (items.len < 2) return false;

        const config = switch (items[1]) {
            .object => |object| object,
            else => return error.UnsupportedRuleConfigValue,
        };
        return switch (config.get("allowIndentationTabs") orelse return false) {
            .bool => |enabled| enabled,
            else => return error.UnsupportedRuleConfigValue,
        };
    }

    fn useIsnanBoolOptionFromConfig(value: std.json.Value, key: []const u8, default: bool) RuleConfigError!bool {
        const items = switch (value) {
            .array => |array| array.items,
            else => return default,
        };
        if (items.len < 2) return default;

        const config = switch (items[1]) {
            .object => |object| object,
            else => return error.UnsupportedRuleConfigValue,
        };
        return switch (config.get(key) orelse return default) {
            .bool => |enabled| enabled,
            else => return error.UnsupportedRuleConfigValue,
        };
    }

    fn noTrailingSpacesBoolOptionFromConfig(value: std.json.Value, key: []const u8) RuleConfigError!bool {
        const items = switch (value) {
            .array => |array| array.items,
            else => return false,
        };
        if (items.len < 2) return false;

        const config = switch (items[1]) {
            .object => |object| object,
            else => return error.UnsupportedRuleConfigValue,
        };
        return switch (config.get(key) orelse return false) {
            .bool => |enabled| enabled,
            else => return error.UnsupportedRuleConfigValue,
        };
    }

    fn noUnsafeNegationBoolOptionFromConfig(value: std.json.Value, key: []const u8, default: bool) RuleConfigError!bool {
        const items = switch (value) {
            .array => |array| array.items,
            else => return default,
        };
        if (items.len < 2) return default;

        const config = switch (items[1]) {
            .object => |object| object,
            else => return error.UnsupportedRuleConfigValue,
        };
        return switch (config.get(key) orelse return default) {
            .bool => |enabled| enabled,
            else => return error.UnsupportedRuleConfigValue,
        };
    }

    fn noIrregularWhitespaceBoolOptionFromConfig(value: std.json.Value, key: []const u8, default: bool) RuleConfigError!bool {
        const items = switch (value) {
            .array => |array| array.items,
            else => return default,
        };
        if (items.len < 2) return default;

        const config = switch (items[1]) {
            .object => |object| object,
            else => return error.UnsupportedRuleConfigValue,
        };
        return switch (config.get(key) orelse return default) {
            .bool => |enabled| enabled,
            else => return error.UnsupportedRuleConfigValue,
        };
    }

    fn noInlineCommentsIgnorePatternFromConfig(value: std.json.Value) RuleConfigError!NoInlineCommentsIgnorePattern {
        const items = switch (value) {
            .array => |array| array.items,
            else => return .{},
        };
        if (items.len < 2) return .{};

        const config = switch (items[1]) {
            .object => |object| object,
            else => return error.UnsupportedRuleConfigValue,
        };
        const pattern_value = switch (config.get("ignorePattern") orelse return .{}) {
            .string => |pattern_value| pattern_value,
            else => return error.UnsupportedRuleConfigValue,
        };
        if (pattern_value.len == 0) return .{};

        var pattern = NoInlineCommentsIgnorePattern{};
        pattern.set(pattern_value) catch return error.UnsupportedRuleConfigValue;
        return pattern;
    }

    fn noMultiAssignBoolOptionFromConfig(value: std.json.Value, key: []const u8, default: bool) RuleConfigError!bool {
        const items = switch (value) {
            .array => |array| array.items,
            else => return default,
        };
        if (items.len < 2) return default;

        const config = switch (items[1]) {
            .object => |object| object,
            else => return error.UnsupportedRuleConfigValue,
        };
        return switch (config.get(key) orelse return default) {
            .bool => |enabled| enabled,
            else => return error.UnsupportedRuleConfigValue,
        };
    }

    fn noEvalAllowIndirectFromConfig(value: std.json.Value) RuleConfigError!bool {
        const items = switch (value) {
            .array => |array| array.items,
            else => return false,
        };
        if (items.len < 2) return false;

        const config = switch (items[1]) {
            .object => |object| object,
            else => return error.UnsupportedRuleConfigValue,
        };
        return switch (config.get("allowIndirect") orelse return false) {
            .bool => |enabled| enabled,
            else => return error.UnsupportedRuleConfigValue,
        };
    }

    fn noExtendNativeExceptionsFromConfig(value: std.json.Value) RuleConfigError!NoExtendNativeExceptions {
        const items = switch (value) {
            .array => |array| array.items,
            else => return .{},
        };
        if (items.len < 2) return .{};

        const config = switch (items[1]) {
            .object => |object| object,
            else => return error.UnsupportedRuleConfigValue,
        };
        const exceptions_value = config.get("exceptions") orelse return .{};
        const exceptions_items = switch (exceptions_value) {
            .array => |array| array.items,
            else => return error.UnsupportedRuleConfigValue,
        };

        var exceptions = NoExtendNativeExceptions{};
        for (exceptions_items) |item| {
            const name = switch (item) {
                .string => |name| name,
                else => return error.UnsupportedRuleConfigValue,
            };
            exceptions.append(name) catch return error.UnsupportedRuleConfigValue;
        }
        return exceptions;
    }

    fn noGlobalAssignExceptionsFromConfig(value: std.json.Value) RuleConfigError!NoShadowAllowNames {
        const items = switch (value) {
            .array => |array| array.items,
            else => return .{},
        };
        if (items.len < 2) return .{};

        const config = switch (items[1]) {
            .object => |object| object,
            else => return error.UnsupportedRuleConfigValue,
        };
        const exceptions_value = config.get("exceptions") orelse return .{};
        const exception_items = switch (exceptions_value) {
            .array => |array| array.items,
            else => return error.UnsupportedRuleConfigValue,
        };

        var exceptions = NoShadowAllowNames{};
        for (exception_items) |item| {
            const name = switch (item) {
                .string => |name| name,
                else => return error.UnsupportedRuleConfigValue,
            };
            exceptions.append(name) catch return error.UnsupportedRuleConfigValue;
        }
        return exceptions;
    }

    fn noUselessRenameBoolOptionFromConfig(value: std.json.Value, key: []const u8) RuleConfigError!bool {
        const items = switch (value) {
            .array => |array| array.items,
            else => return false,
        };
        if (items.len < 2) return false;

        const config = switch (items[1]) {
            .object => |object| object,
            else => return error.UnsupportedRuleConfigValue,
        };
        return switch (config.get(key) orelse return false) {
            .bool => |enabled| enabled,
            else => return error.UnsupportedRuleConfigValue,
        };
    }

    fn noSelfAssignPropsFromConfig(value: std.json.Value) RuleConfigError!bool {
        const items = switch (value) {
            .array => |array| array.items,
            else => return true,
        };
        if (items.len < 2) return true;

        const config = switch (items[1]) {
            .object => |object| object,
            else => return error.UnsupportedRuleConfigValue,
        };
        return switch (config.get("props") orelse return true) {
            .bool => |enabled| enabled,
            else => return error.UnsupportedRuleConfigValue,
        };
    }

    fn unicodeBomStyleFromConfig(value: std.json.Value) RuleConfigError!UnicodeBomStyle {
        const items = switch (value) {
            .array => |array| array.items,
            else => return .never,
        };
        if (items.len < 2) return .never;

        const style = switch (items[1]) {
            .string => |style| style,
            else => return error.UnsupportedRuleConfigValue,
        };
        if (std.mem.eql(u8, style, "never")) return .never;
        if (std.mem.eql(u8, style, "always")) return .always;
        return error.UnsupportedRuleConfigValue;
    }

    fn noUnneededTernaryDefaultAssignmentFromConfig(value: std.json.Value) RuleConfigError!bool {
        const items = switch (value) {
            .array => |array| array.items,
            else => return true,
        };
        if (items.len < 2) return true;

        const config = switch (items[1]) {
            .object => |object| object,
            else => return error.UnsupportedRuleConfigValue,
        };
        return switch (config.get("defaultAssignment") orelse return true) {
            .bool => |enabled| enabled,
            else => error.UnsupportedRuleConfigValue,
        };
    }

    fn noVoidAllowAsStatementFromConfig(value: std.json.Value) RuleConfigError!NoVoidAllowAsStatement {
        const items = switch (value) {
            .array => |array| array.items,
            else => return .no,
        };
        if (items.len < 2) return .no;

        const config = switch (items[1]) {
            .object => |object| object,
            else => return error.UnsupportedRuleConfigValue,
        };
        const allow = switch (config.get("allowAsStatement") orelse return .no) {
            .bool => |enabled| enabled,
            else => return error.UnsupportedRuleConfigValue,
        };
        return if (allow) .yes else .no;
    }

    fn noWarningCommentsLocationFromConfig(value: std.json.Value) RuleConfigError!NoWarningCommentsLocation {
        const items = switch (value) {
            .array => |array| array.items,
            else => return .start,
        };
        if (items.len < 2) return .start;

        const config = switch (items[1]) {
            .object => |object| object,
            else => return error.UnsupportedRuleConfigValue,
        };
        const location = switch (config.get("location") orelse return .start) {
            .string => |location| location,
            else => return error.UnsupportedRuleConfigValue,
        };
        if (std.mem.eql(u8, location, "start")) return .start;
        if (std.mem.eql(u8, location, "anywhere")) return .anywhere;
        return error.UnsupportedRuleConfigValue;
    }

    fn noWarningCommentsDecorationFromConfig(value: std.json.Value) RuleConfigError!NoWarningCommentsDecoration {
        const items = switch (value) {
            .array => |array| array.items,
            else => return .none,
        };
        if (items.len < 2) return .none;

        const config = switch (items[1]) {
            .object => |object| object,
            else => return error.UnsupportedRuleConfigValue,
        };
        const decoration_value = config.get("decoration") orelse return .none;
        const decoration_items = switch (decoration_value) {
            .array => |array| array.items,
            else => return error.UnsupportedRuleConfigValue,
        };

        var has_asterisk = false;
        var has_slash = false;
        for (decoration_items) |item| {
            const char = switch (item) {
                .string => |char| char,
                else => return error.UnsupportedRuleConfigValue,
            };
            if (std.mem.eql(u8, char, "*")) {
                has_asterisk = true;
            } else if (std.mem.eql(u8, char, "/")) {
                has_slash = true;
            } else {
                return error.UnsupportedRuleConfigValue;
            }
        }

        if (has_asterisk and has_slash) return .slash_asterisk;
        if (has_asterisk) return .asterisk;
        if (has_slash) return .slash;
        return .none;
    }

    fn noWarningCommentsTermsFromConfig(value: std.json.Value) RuleConfigError!NoWarningCommentsTerms {
        const items = switch (value) {
            .array => |array| array.items,
            else => return .{},
        };
        if (items.len < 2) return .{};

        const config = switch (items[1]) {
            .object => |object| object,
            else => return error.UnsupportedRuleConfigValue,
        };
        const terms_value = config.get("terms") orelse return .{};
        const term_items = switch (terms_value) {
            .array => |array| array.items,
            else => return error.UnsupportedRuleConfigValue,
        };

        var terms = NoWarningCommentsTerms{};
        terms.custom = true;
        for (term_items) |item| {
            const term = switch (item) {
                .string => |term| term,
                else => return error.UnsupportedRuleConfigValue,
            };
            terms.append(term) catch return error.UnsupportedRuleConfigValue;
        }
        return terms;
    }

    fn spacedCommentStyleFromConfig(value: std.json.Value) RuleConfigError!SpacedCommentStyle {
        const items = switch (value) {
            .array => |array| array.items,
            else => return .always,
        };
        if (items.len < 2) return .always;

        const style = switch (items[1]) {
            .string => |style| style,
            else => return error.UnsupportedRuleConfigValue,
        };
        if (std.mem.eql(u8, style, "always")) return .always;
        if (std.mem.eql(u8, style, "never")) return .never;
        return error.UnsupportedRuleConfigValue;
    }

    fn validTypeofRequireStringLiteralsFromConfig(value: std.json.Value) RuleConfigError!bool {
        const items = switch (value) {
            .array => |array| array.items,
            else => return false,
        };
        if (items.len < 2) return false;

        const config = switch (items[1]) {
            .object => |object| object,
            else => return error.UnsupportedRuleConfigValue,
        };
        return switch (config.get("requireStringLiterals") orelse return false) {
            .bool => |enabled| enabled,
            else => return error.UnsupportedRuleConfigValue,
        };
    }

    fn spacedCommentMarkersFromConfig(value: std.json.Value) RuleConfigError!SpacedCommentMarkers {
        return spacedCommentPatternsFromConfig(value, "markers");
    }

    fn spacedCommentExceptionsFromConfig(value: std.json.Value) RuleConfigError!SpacedCommentMarkers {
        return spacedCommentPatternsFromConfig(value, "exceptions");
    }

    fn spacedCommentPatternsFromConfig(value: std.json.Value, key: []const u8) RuleConfigError!SpacedCommentMarkers {
        const items = switch (value) {
            .array => |array| array.items,
            else => return .{},
        };
        if (items.len < 3) return .{};

        const config = switch (items[2]) {
            .object => |object| object,
            else => return error.UnsupportedRuleConfigValue,
        };
        const patterns_value = config.get(key) orelse return .{};
        const pattern_items = switch (patterns_value) {
            .array => |array| array.items,
            else => return error.UnsupportedRuleConfigValue,
        };

        var patterns = SpacedCommentMarkers{};
        for (pattern_items) |item| {
            const pattern = switch (item) {
                .string => |pattern| pattern,
                else => return error.UnsupportedRuleConfigValue,
            };
            patterns.append(pattern) catch return error.UnsupportedRuleConfigValue;
        }
        return patterns;
    }

    fn reactButtonHasTypeBoolOptionFromConfig(value: std.json.Value, key: []const u8, default: bool) RuleConfigError!bool {
        const items = switch (value) {
            .array => |array| array.items,
            else => return default,
        };
        if (items.len < 2) return default;

        const config = switch (items[1]) {
            .object => |object| object,
            else => return error.UnsupportedRuleConfigValue,
        };
        return switch (config.get(key) orelse return default) {
            .bool => |enabled| enabled,
            else => return error.UnsupportedRuleConfigValue,
        };
    }

    const ReactForbidPropTypesForbid = struct {
        any: bool = true,
        array: bool = true,
        object: bool = true,
    };

    fn reactForbidPropTypesForbidFromConfig(value: std.json.Value) RuleConfigError!ReactForbidPropTypesForbid {
        const items = switch (value) {
            .array => |array| array.items,
            else => return .{},
        };
        if (items.len < 2) return .{};

        const config = switch (items[1]) {
            .object => |object| object,
            else => return error.UnsupportedRuleConfigValue,
        };
        const forbid_items = switch (config.get("forbid") orelse return .{}) {
            .array => |array| array.items,
            else => return error.UnsupportedRuleConfigValue,
        };

        var forbid = ReactForbidPropTypesForbid{
            .any = false,
            .array = false,
            .object = false,
        };
        for (forbid_items) |item| {
            const name = switch (item) {
                .string => |string| string,
                else => return error.UnsupportedRuleConfigValue,
            };
            if (std.mem.eql(u8, name, "any")) {
                forbid.any = true;
            } else if (std.mem.eql(u8, name, "array")) {
                forbid.array = true;
            } else if (std.mem.eql(u8, name, "object")) {
                forbid.object = true;
            } else {
                return error.UnsupportedRuleConfigValue;
            }
        }
        return forbid;
    }

    fn reactJsxFilenameExtensionsFromConfig(value: std.json.Value) RuleConfigError!ReactJsxFilenameExtensions {
        const items = switch (value) {
            .array => |array| array.items,
            else => return .{},
        };
        if (items.len < 2) return .{};

        const config = switch (items[1]) {
            .object => |object| object,
            else => return error.UnsupportedRuleConfigValue,
        };
        const extension_items = switch (config.get("extensions") orelse return .{}) {
            .array => |array| array.items,
            else => return error.UnsupportedRuleConfigValue,
        };

        var extensions = ReactJsxFilenameExtensions{};
        for (extension_items) |item| {
            const extension_name = switch (item) {
                .string => |string| string,
                else => return error.UnsupportedRuleConfigValue,
            };
            extensions.append(extension_name) catch return error.UnsupportedRuleConfigValue;
        }
        return extensions;
    }

    fn reactJsxBooleanValueStyleFromConfig(value: std.json.Value) RuleConfigError!ReactJsxBooleanValueStyle {
        const items = switch (value) {
            .array => |array| array.items,
            else => return .never,
        };
        if (items.len < 2) return .never;

        const style = switch (items[1]) {
            .string => |style| style,
            else => return error.UnsupportedRuleConfigValue,
        };
        if (std.mem.eql(u8, style, "never")) return .never;
        if (std.mem.eql(u8, style, "always")) return .always;
        return error.UnsupportedRuleConfigValue;
    }

    fn reactPreferEs6ClassStyleFromConfig(value: std.json.Value) RuleConfigError!ReactPreferEs6ClassStyle {
        const items = switch (value) {
            .array => |array| array.items,
            else => return .always,
        };
        if (items.len < 2) return .always;

        const style = switch (items[1]) {
            .string => |style| style,
            else => return error.UnsupportedRuleConfigValue,
        };
        if (std.mem.eql(u8, style, "always")) return .always;
        if (std.mem.eql(u8, style, "never")) return .never;
        return error.UnsupportedRuleConfigValue;
    }

    fn reactDefaultPropsMatchPropTypesAllowRequiredDefaultsFromConfig(value: std.json.Value) RuleConfigError!bool {
        const items = switch (value) {
            .array => |array| array.items,
            else => return false,
        };
        if (items.len < 2) return false;

        const config = switch (items[1]) {
            .object => |object| object,
            else => return error.UnsupportedRuleConfigValue,
        };
        return switch (config.get("allowRequiredDefaults") orelse return false) {
            .bool => |enabled| enabled,
            else => error.UnsupportedRuleConfigValue,
        };
    }

    fn reactDisplayNameBoolOptionFromConfig(value: std.json.Value, key: []const u8, default: bool) RuleConfigError!bool {
        const items = switch (value) {
            .array => |array| array.items,
            else => return default,
        };
        if (items.len < 2) return default;

        const config = switch (items[1]) {
            .object => |object| object,
            else => return error.UnsupportedRuleConfigValue,
        };
        return switch (config.get(key) orelse return default) {
            .bool => |enabled| enabled,
            else => error.UnsupportedRuleConfigValue,
        };
    }

    fn reactJsxNoBindBoolOptionFromConfig(value: std.json.Value, key: []const u8, default: bool) RuleConfigError!bool {
        const items = switch (value) {
            .array => |array| array.items,
            else => return default,
        };
        if (items.len < 2) return default;

        const config = switch (items[1]) {
            .object => |object| object,
            else => return error.UnsupportedRuleConfigValue,
        };
        return switch (config.get(key) orelse return default) {
            .bool => |enabled| enabled,
            else => error.UnsupportedRuleConfigValue,
        };
    }

    fn reactJsxNoDuplicatePropsIgnoreCaseFromConfig(value: std.json.Value) RuleConfigError!bool {
        const items = switch (value) {
            .array => |array| array.items,
            else => return true,
        };
        if (items.len < 2) return true;

        const config = switch (items[1]) {
            .object => |object| object,
            else => return error.UnsupportedRuleConfigValue,
        };
        return switch (config.get("ignoreCase") orelse return true) {
            .bool => |ignore_case| ignore_case,
            else => error.UnsupportedRuleConfigValue,
        };
    }

    fn reactJsxKeyCheckKeyMustBeforeSpreadFromConfig(value: std.json.Value) RuleConfigError!bool {
        const items = switch (value) {
            .array => |array| array.items,
            else => return false,
        };
        if (items.len < 2) return false;

        const config = switch (items[1]) {
            .object => |object| object,
            else => return error.UnsupportedRuleConfigValue,
        };
        return switch (config.get("checkKeyMustBeforeSpread") orelse return false) {
            .bool => |enabled| enabled,
            else => error.UnsupportedRuleConfigValue,
        };
    }

    fn reactJsxKeyCheckFragmentShorthandFromConfig(value: std.json.Value) RuleConfigError!bool {
        const items = switch (value) {
            .array => |array| array.items,
            else => return false,
        };
        if (items.len < 2) return false;

        const config = switch (items[1]) {
            .object => |object| object,
            else => return error.UnsupportedRuleConfigValue,
        };
        return switch (config.get("checkFragmentShorthand") orelse return false) {
            .bool => |enabled| enabled,
            else => error.UnsupportedRuleConfigValue,
        };
    }

    fn reactNoStringRefsNoTemplateLiteralsFromConfig(value: std.json.Value) RuleConfigError!bool {
        const items = switch (value) {
            .array => |array| array.items,
            else => return false,
        };
        if (items.len < 2) return false;

        const config = switch (items[1]) {
            .object => |object| object,
            else => return error.UnsupportedRuleConfigValue,
        };
        return switch (config.get("noTemplateLiterals") orelse return false) {
            .bool => |no_template_literals| no_template_literals,
            else => error.UnsupportedRuleConfigValue,
        };
    }

    fn reactNoMultiCompIgnoreStatelessFromConfig(value: std.json.Value) RuleConfigError!bool {
        const items = switch (value) {
            .array => |array| array.items,
            else => return true,
        };
        if (items.len < 2) return true;

        const config = switch (items[1]) {
            .object => |object| object,
            else => return error.UnsupportedRuleConfigValue,
        };
        return switch (config.get("ignoreStateless") orelse return true) {
            .bool => |ignore_stateless| ignore_stateless,
            else => error.UnsupportedRuleConfigValue,
        };
    }

    fn reactNoUnknownPropertyIgnoreFromConfig(value: std.json.Value) RuleConfigError!ReactNoUnknownPropertyIgnoreNames {
        const items = switch (value) {
            .array => |array| array.items,
            else => return .{},
        };
        if (items.len < 2) return .{};

        const config = switch (items[1]) {
            .object => |object| object,
            else => return error.UnsupportedRuleConfigValue,
        };
        const ignore_items = switch (config.get("ignore") orelse return .{}) {
            .array => |array| array.items,
            else => return error.UnsupportedRuleConfigValue,
        };

        var ignore = ReactNoUnknownPropertyIgnoreNames{};
        for (ignore_items) |item| {
            const name = switch (item) {
                .string => |string| string,
                else => return error.UnsupportedRuleConfigValue,
            };
            ignore.append(name) catch return error.UnsupportedRuleConfigValue;
        }
        return ignore;
    }

    fn reactNoUnknownPropertyRequireDataLowercaseFromConfig(value: std.json.Value) RuleConfigError!bool {
        const items = switch (value) {
            .array => |array| array.items,
            else => return false,
        };
        if (items.len < 2) return false;

        const config = switch (items[1]) {
            .object => |object| object,
            else => return error.UnsupportedRuleConfigValue,
        };
        return switch (config.get("requireDataLowercase") orelse return false) {
            .bool => |require_data_lowercase| require_data_lowercase,
            else => error.UnsupportedRuleConfigValue,
        };
    }

    fn reactSelfClosingCompBoolOptionFromConfig(value: std.json.Value, key: []const u8, default: bool) RuleConfigError!bool {
        const items = switch (value) {
            .array => |array| array.items,
            else => return default,
        };
        if (items.len < 2) return default;

        const config = switch (items[1]) {
            .object => |object| object,
            else => return error.UnsupportedRuleConfigValue,
        };
        return switch (config.get(key) orelse return default) {
            .bool => |enabled| enabled,
            else => error.UnsupportedRuleConfigValue,
        };
    }

    fn reactJsxPascalCaseAllowAllCapsFromConfig(value: std.json.Value) RuleConfigError!bool {
        const items = switch (value) {
            .array => |array| array.items,
            else => return true,
        };
        if (items.len < 2) return true;

        const config = switch (items[1]) {
            .object => |object| object,
            else => return error.UnsupportedRuleConfigValue,
        };
        return switch (config.get("allowAllCaps") orelse return true) {
            .bool => |allow_all_caps| allow_all_caps,
            else => error.UnsupportedRuleConfigValue,
        };
    }

    fn reactJsxPascalCaseIgnoreFromConfig(value: std.json.Value) RuleConfigError!ReactJsxPascalCaseIgnoreNames {
        const items = switch (value) {
            .array => |array| array.items,
            else => return .{},
        };
        if (items.len < 2) return .{};

        const config = switch (items[1]) {
            .object => |object| object,
            else => return error.UnsupportedRuleConfigValue,
        };
        const ignore_items = switch (config.get("ignore") orelse return .{}) {
            .array => |array| array.items,
            else => return error.UnsupportedRuleConfigValue,
        };

        var ignore = ReactJsxPascalCaseIgnoreNames{};
        for (ignore_items) |item| {
            const name = switch (item) {
                .string => |string| string,
                else => return error.UnsupportedRuleConfigValue,
            };
            ignore.append(name) catch return error.UnsupportedRuleConfigValue;
        }
        return ignore;
    }

    fn wrapIifeStyleFromConfig(value: std.json.Value) RuleConfigError!WrapIifeStyle {
        const items = switch (value) {
            .array => |array| array.items,
            else => return .outside,
        };
        if (items.len < 2) return .outside;

        const style = switch (items[1]) {
            .string => |style| style,
            else => return error.UnsupportedRuleConfigValue,
        };
        if (std.mem.eql(u8, style, "outside")) return .outside;
        if (std.mem.eql(u8, style, "inside")) return .inside;
        if (std.mem.eql(u8, style, "any")) return .any;
        return error.UnsupportedRuleConfigValue;
    }

    fn yodaStyleFromConfig(value: std.json.Value) RuleConfigError!YodaStyle {
        const items = switch (value) {
            .array => |array| array.items,
            else => return .never,
        };
        if (items.len < 2) return .never;

        const style = switch (items[1]) {
            .string => |style| style,
            .object => return .never,
            else => return error.UnsupportedRuleConfigValue,
        };
        if (std.mem.eql(u8, style, "never")) return .never;
        if (std.mem.eql(u8, style, "always")) return .always;
        return error.UnsupportedRuleConfigValue;
    }

    fn yodaOnlyEqualityFromConfig(value: std.json.Value) RuleConfigError!bool {
        const items = switch (value) {
            .array => |array| array.items,
            else => return false,
        };
        if (items.len < 2) return false;

        const config_value = switch (items[1]) {
            .object => items[1],
            .string => if (items.len >= 3) items[2] else return false,
            else => return error.UnsupportedRuleConfigValue,
        };
        const config = switch (config_value) {
            .object => |object| object,
            else => return error.UnsupportedRuleConfigValue,
        };
        return switch (config.get("onlyEquality") orelse return false) {
            .bool => |enabled| enabled,
            else => error.UnsupportedRuleConfigValue,
        };
    }

    fn yodaExceptRangeFromConfig(value: std.json.Value) RuleConfigError!bool {
        const items = switch (value) {
            .array => |array| array.items,
            else => return false,
        };
        if (items.len < 3) return false;

        const config = switch (items[2]) {
            .object => |object| object,
            else => return error.UnsupportedRuleConfigValue,
        };
        return switch (config.get("exceptRange") orelse return false) {
            .bool => |enabled| enabled,
            else => return error.UnsupportedRuleConfigValue,
        };
    }

    fn typescriptEslintMethodSignatureStyleFromConfig(value: std.json.Value) RuleConfigError!TypescriptEslintMethodSignatureStyle {
        const items = switch (value) {
            .array => |array| array.items,
            else => return .property,
        };
        if (items.len < 2) return .property;

        const style = switch (items[1]) {
            .string => |style| style,
            else => return error.UnsupportedRuleConfigValue,
        };
        if (std.mem.eql(u8, style, "property")) return .property;
        if (std.mem.eql(u8, style, "method")) return .method;
        return error.UnsupportedRuleConfigValue;
    }

    fn typescriptEslintArrayTypeStyleFromConfig(value: std.json.Value) RuleConfigError!TypescriptEslintArrayTypeStyle {
        const items = switch (value) {
            .array => |array| array.items,
            else => return .array_simple,
        };
        if (items.len < 2) return .array_simple;

        const config_value = switch (items[1]) {
            .object => items[1],
            else => return error.UnsupportedRuleConfigValue,
        };
        const config = switch (config_value) {
            .object => |object| object,
            else => return error.UnsupportedRuleConfigValue,
        };
        const style = switch (config.get("default") orelse return .array_simple) {
            .string => |style| style,
            else => return error.UnsupportedRuleConfigValue,
        };
        if (std.mem.eql(u8, style, "array")) return .array;
        if (std.mem.eql(u8, style, "array-simple")) return .array_simple;
        if (std.mem.eql(u8, style, "generic")) return .generic;
        return error.UnsupportedRuleConfigValue;
    }

    fn typescriptEslintBanTsCommentModeFromConfig(value: std.json.Value, key: []const u8, default: TypescriptEslintBanTsCommentMode) RuleConfigError!TypescriptEslintBanTsCommentMode {
        const items = switch (value) {
            .array => |array| array.items,
            else => return default,
        };
        if (items.len < 2) return default;

        const config = switch (items[1]) {
            .object => |object| object,
            else => return error.UnsupportedRuleConfigValue,
        };
        return switch (config.get(key) orelse return default) {
            .bool => |enabled| if (enabled) .ban else .allow,
            .string => |mode| if (std.mem.eql(u8, mode, "allow-with-description"))
                .allow_with_description
            else
                error.UnsupportedRuleConfigValue,
            else => error.UnsupportedRuleConfigValue,
        };
    }

    fn typescriptEslintBanTsCommentMinimumDescriptionLengthFromConfig(value: std.json.Value) RuleConfigError!usize {
        const items = switch (value) {
            .array => |array| array.items,
            else => return 3,
        };
        if (items.len < 2) return 3;

        const config = switch (items[1]) {
            .object => |object| object,
            else => return error.UnsupportedRuleConfigValue,
        };
        const length = switch (config.get("minimumDescriptionLength") orelse return 3) {
            .integer => |length| length,
            else => return error.UnsupportedRuleConfigValue,
        };
        if (length < 0) return error.UnsupportedRuleConfigValue;
        return @intCast(length);
    }

    fn typescriptEslintConsistentTypeDefinitionsStyleFromConfig(value: std.json.Value) RuleConfigError!TypescriptEslintConsistentTypeDefinitionsStyle {
        const items = switch (value) {
            .array => |array| array.items,
            else => return .interface,
        };
        if (items.len < 2) return .interface;

        const style = switch (items[1]) {
            .string => |style| style,
            else => return error.UnsupportedRuleConfigValue,
        };
        if (std.mem.eql(u8, style, "interface")) return .interface;
        if (std.mem.eql(u8, style, "type")) return .type;
        return error.UnsupportedRuleConfigValue;
    }

    fn typescriptEslintClassLiteralPropertyStyleFromConfig(value: std.json.Value) RuleConfigError!TypescriptEslintClassLiteralPropertyStyle {
        const items = switch (value) {
            .array => |array| array.items,
            else => return .fields,
        };
        if (items.len < 2) return .fields;

        const style = switch (items[1]) {
            .string => |style| style,
            else => return error.UnsupportedRuleConfigValue,
        };
        if (std.mem.eql(u8, style, "fields")) return .fields;
        if (std.mem.eql(u8, style, "getters")) return .getters;
        return error.UnsupportedRuleConfigValue;
    }

    fn typescriptEslintTripleSlashReferenceModeFromConfig(value: std.json.Value, key: []const u8, default: TypescriptEslintTripleSlashReferenceMode) RuleConfigError!TypescriptEslintTripleSlashReferenceMode {
        const items = switch (value) {
            .array => |array| array.items,
            else => return default,
        };
        if (items.len < 2) return default;

        const config = switch (items[1]) {
            .object => |object| object,
            else => return error.UnsupportedRuleConfigValue,
        };
        const mode = switch (config.get(key) orelse return default) {
            .string => |mode| mode,
            else => return error.UnsupportedRuleConfigValue,
        };
        if (std.mem.eql(u8, mode, "always")) return .always;
        if (std.mem.eql(u8, mode, "never")) return .never;
        return error.UnsupportedRuleConfigValue;
    }

    fn typescriptEslintNoNamespaceBoolOptionFromConfig(value: std.json.Value, key: []const u8, default: bool) RuleConfigError!bool {
        const items = switch (value) {
            .array => |array| array.items,
            else => return default,
        };
        if (items.len < 2) return default;

        const config = switch (items[1]) {
            .object => |object| object,
            else => return error.UnsupportedRuleConfigValue,
        };
        return switch (config.get(key) orelse return default) {
            .bool => |enabled| enabled,
            else => return error.UnsupportedRuleConfigValue,
        };
    }

    fn typescriptEslintNoRedeclareIgnoreDeclarationMergeFromConfig(value: std.json.Value) RuleConfigError!bool {
        return typescriptEslintNoNamespaceBoolOptionFromConfig(value, "ignoreDeclarationMerge", true);
    }

    fn typescriptEslintNoRedeclareBuiltinGlobalsFromConfig(value: std.json.Value) RuleConfigError!bool {
        return noShadowBuiltinGlobalsFromConfig(value);
    }

    fn typescriptEslintNoThisAliasAllowedNamesFromConfig(value: std.json.Value) RuleConfigError!NoThisAliasAllowedNames {
        const items = switch (value) {
            .array => |array| array.items,
            else => return .{},
        };
        if (items.len < 2) return .{};

        const config = switch (items[1]) {
            .object => |object| object,
            else => return error.UnsupportedRuleConfigValue,
        };
        const allowed_names_value = config.get("allowedNames") orelse return .{};
        const allowed_names = switch (allowed_names_value) {
            .array => |array| array.items,
            else => return error.UnsupportedRuleConfigValue,
        };

        var names = NoThisAliasAllowedNames{ .custom = true };
        for (allowed_names) |name_value| {
            const name = switch (name_value) {
                .string => |name| name,
                else => return error.UnsupportedRuleConfigValue,
            };
            names.append(name) catch return error.UnsupportedRuleConfigValue;
        }
        return names;
    }

    fn typescriptEslintNoInferrableTypesBoolOptionFromConfig(value: std.json.Value, key: []const u8, default: bool) RuleConfigError!bool {
        const items = switch (value) {
            .array => |array| array.items,
            else => return default,
        };
        if (items.len < 2) return default;

        const config = switch (items[1]) {
            .object => |object| object,
            else => return error.UnsupportedRuleConfigValue,
        };
        return switch (config.get(key) orelse return default) {
            .bool => |enabled| enabled,
            else => return error.UnsupportedRuleConfigValue,
        };
    }

    fn typescriptEslintNoInvalidVoidTypeBoolOptionFromConfig(value: std.json.Value, key: []const u8, default: bool) RuleConfigError!bool {
        const items = switch (value) {
            .array => |array| array.items,
            else => return default,
        };
        if (items.len < 2) return default;

        const config = switch (items[1]) {
            .object => |object| object,
            else => return error.UnsupportedRuleConfigValue,
        };
        return switch (config.get(key) orelse return default) {
            .bool => |enabled| enabled,
            else => return error.UnsupportedRuleConfigValue,
        };
    }

    fn typescriptEslintNoEmptyInterfaceAllowSingleExtendsFromConfig(value: std.json.Value) RuleConfigError!bool {
        const items = switch (value) {
            .array => |array| array.items,
            else => return false,
        };
        if (items.len < 2) return false;

        const config = switch (items[1]) {
            .object => |object| object,
            else => return error.UnsupportedRuleConfigValue,
        };
        return switch (config.get("allowSingleExtends") orelse return false) {
            .bool => |enabled| enabled,
            else => return error.UnsupportedRuleConfigValue,
        };
    }

    fn typescriptEslintTypedefBoolOptionFromConfig(value: std.json.Value, key: []const u8, default: bool) RuleConfigError!bool {
        const items = switch (value) {
            .array => |array| array.items,
            else => return default,
        };
        if (items.len < 2) return default;

        const config = switch (items[1]) {
            .object => |object| object,
            else => return error.UnsupportedRuleConfigValue,
        };
        return switch (config.get(key) orelse return default) {
            .bool => |enabled| enabled,
            else => return error.UnsupportedRuleConfigValue,
        };
    }

    fn typescriptEslintRestrictPlusOperandsBoolOptionFromConfig(value: std.json.Value, key: []const u8, default: bool) RuleConfigError!bool {
        const items = switch (value) {
            .array => |array| array.items,
            else => return default,
        };
        if (items.len < 2) return default;

        const config = switch (items[1]) {
            .object => |object| object,
            else => return error.UnsupportedRuleConfigValue,
        };
        return switch (config.get(key) orelse return default) {
            .bool => |enabled| enabled,
            else => return error.UnsupportedRuleConfigValue,
        };
    }

    fn setByPrefixedRuleName(self: *Options, comptime field_prefix: []const u8, rule_name: []const u8, value: bool) bool {
        inline for (@typeInfo(Options).@"struct".fields) |field| {
            if (field.type == bool) {
                if (comptime fieldNameStartsWith(field.name, field_prefix)) {
                    if (cliNameMatchesFieldName(field.name[field_prefix.len..], rule_name)) {
                        @field(self, field.name) = value;
                        return true;
                    }
                }
            }
        }
        return false;
    }

    fn cliNameMatchesFieldName(comptime field_name: []const u8, cli_name: []const u8) bool {
        if (cli_name.len != field_name.len) return false;

        comptime var index: usize = 0;
        inline while (index < field_name.len) : (index += 1) {
            const expected = if (field_name[index] == '_') '-' else field_name[index];
            if (cli_name[index] != expected) return false;
        }
        return true;
    }

    fn fieldNameStartsWith(comptime field_name: []const u8, comptime prefix: []const u8) bool {
        @setEvalBranchQuota(10_000);
        if (field_name.len < prefix.len) return false;

        comptime var index: usize = 0;
        inline while (index < prefix.len) : (index += 1) {
            if (field_name[index] != prefix[index]) return false;
        }
        return true;
    }
};

pub const DeprecatedDependenceProfile = enum {
    default,
    profile_a,
    profile_b,
};

pub const Diagnostic = struct {
    rule_id: []const u8,
    message: []const u8,
    span: ast.Span,
    severity: Severity,
};

pub const Result = struct {
    diagnostics: []Diagnostic,

    pub fn deinit(self: *Result, allocator: Allocator) void {
        for (self.diagnostics) |diagnostic| {
            allocator.free(diagnostic.message);
        }
        allocator.free(self.diagnostics);
    }

    pub fn hasDiagnostics(self: Result) bool {
        return self.diagnostics.len > 0;
    }

    pub fn hasErrors(self: Result) bool {
        for (self.diagnostics) |diagnostic| {
            if (diagnostic.severity == .@"error") return true;
        }
        return false;
    }
};

pub const SourcePosition = struct {
    line: usize,
    column: usize,
};

pub const DiagnosticList = std.ArrayList(Diagnostic);

pub fn addDiagnostic(
    allocator: Allocator,
    diagnostics: *DiagnosticList,
    severity: Severity,
    rule_id: []const u8,
    message: []const u8,
    span: ast.Span,
) Allocator.Error!void {
    const owned_message = try allocator.dupe(u8, message);
    errdefer allocator.free(owned_message);

    try diagnostics.append(allocator, .{
        .rule_id = rule_id,
        .message = owned_message,
        .span = span,
        .severity = severity,
    });
}

pub fn addDiagnosticFmt(
    allocator: Allocator,
    diagnostics: *DiagnosticList,
    severity: Severity,
    rule_id: []const u8,
    span: ast.Span,
    comptime fmt: []const u8,
    args: anytype,
) Allocator.Error!void {
    const owned_message = try std.fmt.allocPrint(allocator, fmt, args);
    errdefer allocator.free(owned_message);

    try diagnostics.append(allocator, .{
        .rule_id = rule_id,
        .message = owned_message,
        .span = span,
        .severity = severity,
    });
}

pub fn freeDiagnostics(allocator: Allocator, diagnostics: *DiagnosticList) void {
    for (diagnostics.items) |diagnostic| {
        allocator.free(diagnostic.message);
    }
    diagnostics.deinit(allocator);
}

pub fn isKnownGlobal(name: []const u8) bool {
    const globals = [_][]const u8{
        "alert",
        "Array",
        "BigInt",
        "Boolean",
        "Buffer",
        "confirm",
        "Date",
        "Error",
        "Headers",
        "Infinity",
        "Intl",
        "isFinite",
        "isNaN",
        "JSON",
        "Map",
        "Math",
        "NaN",
        "Number",
        "Object",
        "Promise",
        "RegExp",
        "Request",
        "Response",
        "Set",
        "String",
        "Symbol",
        "URL",
        "URLSearchParams",
        "WeakMap",
        "WeakSet",
        "__dirname",
        "__filename",
        "clearInterval",
        "clearTimeout",
        "console",
        "document",
        "exports",
        "fetch",
        "global",
        "globalThis",
        "module",
        "process",
        "prompt",
        "queueMicrotask",
        "require",
        "setInterval",
        "setTimeout",
        "undefined",
        "window",
    };

    for (globals) |global| {
        if (std.mem.eql(u8, name, global)) return true;
    }

    return false;
}

test "Options can enable rules by CLI name" {
    var options = Options.allDisabled();

    try std.testing.expect(!options.no_debugger);
    try std.testing.expect(options.setByCliName("no-debugger", true));
    try std.testing.expect(options.no_debugger);

    try std.testing.expect(!options.typescript_eslint_no_unused_vars);
    try std.testing.expect(options.setByCliName("@typescript-eslint/no-unused-vars", true));
    try std.testing.expect(options.typescript_eslint_no_unused_vars);
    try std.testing.expect(!options.no_unused_vars);

    try std.testing.expect(!options.typescript_eslint_no_inferrable_types);
    try std.testing.expect(options.setByCliName("@typescript-eslint/no-inferrable-types", true));
    try std.testing.expect(options.typescript_eslint_no_inferrable_types);
    try std.testing.expect(!options.typescript_eslint_no_inferrable_types_ignore_parameters);
    try std.testing.expect(!options.typescript_eslint_no_inferrable_types_ignore_properties);

    try std.testing.expect(!options.typescript_eslint_no_empty_interface);
    try std.testing.expect(options.setByCliName("@typescript-eslint/no-empty-interface", true));
    try std.testing.expect(options.typescript_eslint_no_empty_interface);
    try std.testing.expect(!options.typescript_eslint_no_empty_interface_allow_single_extends);

    try std.testing.expect(!options.typescript_eslint_restrict_plus_operands);
    try std.testing.expect(options.setByCliName("@typescript-eslint/restrict-plus-operands", true));
    try std.testing.expect(options.typescript_eslint_restrict_plus_operands);
    try std.testing.expect(!options.typescript_eslint_restrict_plus_operands_allow_number_and_string);

    try std.testing.expect(!options.typescript_eslint_no_duplicate_enum_values);
    try std.testing.expect(options.setByCliName("@typescript-eslint/no-duplicate-enum-values", true));
    try std.testing.expect(options.typescript_eslint_no_duplicate_enum_values);

    try std.testing.expect(!options.typescript_eslint_no_useless_empty_export);
    try std.testing.expect(options.setByCliName("@typescript-eslint/no-useless-empty-export", true));
    try std.testing.expect(options.typescript_eslint_no_useless_empty_export);

    try std.testing.expect(!options.typescript_eslint_no_wrapper_object_types);
    try std.testing.expect(options.setByCliName("@typescript-eslint/no-wrapper-object-types", true));
    try std.testing.expect(options.typescript_eslint_no_wrapper_object_types);

    try std.testing.expect(!options.typescript_eslint_no_unnecessary_parameter_property_assignment);
    try std.testing.expect(options.setByCliName("@typescript-eslint/no-unnecessary-parameter-property-assignment", true));
    try std.testing.expect(options.typescript_eslint_no_unnecessary_parameter_property_assignment);

    try std.testing.expect(!options.typescript_eslint_no_unsafe_declaration_merging);
    try std.testing.expect(options.setByCliName("@typescript-eslint/no-unsafe-declaration-merging", true));
    try std.testing.expect(options.typescript_eslint_no_unsafe_declaration_merging);

    try std.testing.expect(!options.jsx_a11y_aria_props);
    try std.testing.expect(options.setByCliName("jsx-a11y/aria-props", true));
    try std.testing.expect(options.jsx_a11y_aria_props);

    try std.testing.expect(!options.react_jsx_no_target_blank);
    try std.testing.expect(options.setByCliName("react/jsx-no-target-blank", true));
    try std.testing.expect(options.react_jsx_no_target_blank);
    try std.testing.expect(!options.react_jsx_no_target_blank_allow_referrer);
    try std.testing.expect(options.react_jsx_no_target_blank_enforce_dynamic_links);

    try std.testing.expect(!options.import_no_duplicates);
    try std.testing.expect(options.setByCliName("import/no-duplicates", true));
    try std.testing.expect(options.import_no_duplicates);

    try std.testing.expect(!options.alipay_ant_no_import_src);
    try std.testing.expect(options.setByCliName("@alipay/ant/no-import-src", true));
    try std.testing.expect(options.alipay_ant_no_import_src);

    try std.testing.expect(!options.alipay_ant_no_phantom_dependencies);
    try std.testing.expect(options.setByCliName("@alipay/ant/no-phantom-dependencies", true));
    try std.testing.expect(options.alipay_ant_no_phantom_dependencies);

    try std.testing.expect(!options.alipay_ant_disallow_typos);
    try std.testing.expect(options.setByCliName("@alipay/ant/disallow-typos", true));
    try std.testing.expect(options.alipay_ant_disallow_typos);

    try std.testing.expect(!options.alipay_spmlint_use_labeled_spm);
    try std.testing.expect(options.setByCliName("@alipay/spmLint/use-labeled-spm", true));
    try std.testing.expect(options.alipay_spmlint_use_labeled_spm);

    try std.testing.expect(!options.alipay_spmlint_valid_manual_click);
    try std.testing.expect(options.setByCliName("@alipay/spmLint/valid-manual-click", true));
    try std.testing.expect(options.alipay_spmlint_valid_manual_click);

    try std.testing.expect(!options.alipay_spmlint_valid_manual_expo);
    try std.testing.expect(options.setByCliName("@alipay/spmLint/valid-manual-expo", true));
    try std.testing.expect(options.alipay_spmlint_valid_manual_expo);

    try std.testing.expect(!options.alipay_spmlint_valid_manual_param);
    try std.testing.expect(options.setByCliName("@alipay/spmLint/valid-manual-param", true));
    try std.testing.expect(options.alipay_spmlint_valid_manual_param);

    try std.testing.expect(!options.alipay_spmlint_valid_manual_pv);
    try std.testing.expect(options.setByCliName("@alipay/spmLint/valid-manual-pv", true));
    try std.testing.expect(options.alipay_spmlint_valid_manual_pv);

    try std.testing.expect(!options.import_default);
    try std.testing.expect(options.setByCliName("import/default", true));
    try std.testing.expect(options.import_default);

    try std.testing.expect(!options.import_export);
    try std.testing.expect(options.setByCliName("import/export", true));
    try std.testing.expect(options.import_export);

    try std.testing.expect(!options.import_named);
    try std.testing.expect(options.setByCliName("import/named", true));
    try std.testing.expect(options.import_named);

    try std.testing.expect(!options.import_namespace);
    try std.testing.expect(options.setByCliName("import/namespace", true));
    try std.testing.expect(options.import_namespace);

    try std.testing.expect(!options.import_no_cycle);
    try std.testing.expect(options.setByCliName("import/no-cycle", true));
    try std.testing.expect(options.import_no_cycle);

    try std.testing.expect(!options.import_no_named_as_default);
    try std.testing.expect(options.setByCliName("import/no-named-as-default", true));
    try std.testing.expect(options.import_no_named_as_default);

    try std.testing.expect(!options.import_no_named_as_default_member);
    try std.testing.expect(options.setByCliName("import/no-named-as-default-member", true));
    try std.testing.expect(options.import_no_named_as_default_member);

    try std.testing.expect(!options.import_no_unresolved);
    try std.testing.expect(options.setByCliName("import/no-unresolved", true));
    try std.testing.expect(options.import_no_unresolved);

    try std.testing.expect(!options.react_default_props_match_prop_types);
    try std.testing.expect(options.setByCliName("react/default-props-match-prop-types", true));
    try std.testing.expect(options.react_default_props_match_prop_types);

    try std.testing.expect(!options.react_button_has_type);
    try std.testing.expect(options.setByCliName("react/button-has-type", true));
    try std.testing.expect(options.react_button_has_type);
    try std.testing.expect(options.react_button_has_type_button);
    try std.testing.expect(options.react_button_has_type_submit);
    try std.testing.expect(options.react_button_has_type_reset);

    try std.testing.expect(!options.react_forbid_prop_types);
    try std.testing.expect(options.setByCliName("react/forbid-prop-types", true));
    try std.testing.expect(options.react_forbid_prop_types);
    try std.testing.expect(options.react_forbid_prop_types_forbid_any);
    try std.testing.expect(options.react_forbid_prop_types_forbid_array);
    try std.testing.expect(options.react_forbid_prop_types_forbid_object);

    try std.testing.expect(!options.react_jsx_filename_extension);
    try std.testing.expect(options.setByCliName("react/jsx-filename-extension", true));
    try std.testing.expect(options.react_jsx_filename_extension);
    try std.testing.expectEqual(react_jsx_filename_extension_default_extensions.len, options.react_jsx_filename_extension_extensions.len());

    try std.testing.expect(!options.react_jsx_no_bind);
    try std.testing.expect(options.setByCliName("react/jsx-no-bind", true));
    try std.testing.expect(options.react_jsx_no_bind);
    try std.testing.expect(!options.react_jsx_no_bind_allow_arrow_functions);
    try std.testing.expect(!options.react_jsx_no_bind_allow_functions);
    try std.testing.expect(!options.react_jsx_no_bind_allow_bind);
    try std.testing.expect(!options.react_jsx_no_bind_ignore_refs);
    try std.testing.expect(!options.react_jsx_no_bind_ignore_dom_components);

    try std.testing.expect(!options.react_jsx_key);
    try std.testing.expect(options.setByCliName("react/jsx-key", true));
    try std.testing.expect(options.react_jsx_key);
    try std.testing.expect(!options.react_jsx_key_check_key_must_before_spread);

    try std.testing.expect(!options.react_prop_types);
    try std.testing.expect(options.setByCliName("react/prop-types", true));
    try std.testing.expect(options.react_prop_types);
    try std.testing.expect(!options.react_prop_types_skip_undeclared);

    try std.testing.expect(!options.react_no_unused_prop_types);
    try std.testing.expect(options.setByCliName("react/no-unused-prop-types", true));
    try std.testing.expect(options.react_no_unused_prop_types);
    try std.testing.expect(options.react_no_unused_prop_types_skip_shape_props);
    try std.testing.expectEqual(@as(usize, 0), options.react_jsx_pascal_case_ignore.count);

    try std.testing.expect(!options.react_no_string_refs);
    try std.testing.expect(options.setByCliName("react/no-string-refs", true));
    try std.testing.expect(options.react_no_string_refs);
    try std.testing.expect(!options.react_no_string_refs_no_template_literals);

    try std.testing.expect(!options.react_no_multi_comp);
    try std.testing.expect(options.setByCliName("react/no-multi-comp", true));
    try std.testing.expect(options.react_no_multi_comp);
    try std.testing.expect(options.react_no_multi_comp_ignore_stateless);

    try std.testing.expect(!options.react_no_unknown_property);
    try std.testing.expect(options.setByCliName("react/no-unknown-property", true));
    try std.testing.expect(options.react_no_unknown_property);
    try std.testing.expectEqual(@as(usize, 0), options.react_no_unknown_property_ignore.count);
    try std.testing.expect(!options.react_no_unknown_property_require_data_lowercase);

    try std.testing.expect(!options.react_self_closing_comp);
    try std.testing.expect(options.setByCliName("react/self-closing-comp", true));
    try std.testing.expect(options.react_self_closing_comp);
    try std.testing.expect(options.react_self_closing_comp_component);
    try std.testing.expect(options.react_self_closing_comp_html);

    try std.testing.expect(!options.react_no_unescaped_entities);
    try std.testing.expect(options.setByCliName("react/no-unescaped-entities", true));
    try std.testing.expect(options.react_no_unescaped_entities);
    try std.testing.expect(options.react_no_unescaped_entities_forbid_gt);
    try std.testing.expect(options.react_no_unescaped_entities_forbid_double_quote);
    try std.testing.expect(options.react_no_unescaped_entities_forbid_single_quote);
    try std.testing.expect(options.react_no_unescaped_entities_forbid_closing_brace);

    try std.testing.expect(!options.react_hooks_rules_of_hooks);
    try std.testing.expect(options.setByCliName("react-hooks/rules-of-hooks", true));
    try std.testing.expect(options.react_hooks_rules_of_hooks);

    try std.testing.expect(!options.setByCliName("unknown-rule", true));
}

test "Options can apply ESLint-style rule config values" {
    var options = Options{};

    try options.setByRuleConfigValue("no-debugger", .{ .string = "off" });
    try std.testing.expect(!options.no_debugger);

    try options.setByRuleConfigValue("no-debugger", .{ .integer = 2 });
    try std.testing.expect(options.no_debugger);

    var array = std.json.Array.init(std.testing.allocator);
    defer array.deinit();
    try array.append(.{ .string = "warn" });
    try options.setByRuleConfigValue("jsx-a11y/aria-props", .{ .array = array });
    try std.testing.expect(options.jsx_a11y_aria_props);

    try options.setByRuleConfigValue("prettier/prettier", .{ .string = "error" });

    var react_button_has_type_config = try std.json.parseFromSlice(
        std.json.Value,
        std.testing.allocator,
        "[\"error\",{\"button\":true,\"submit\":false,\"reset\":false}]",
        .{},
    );
    defer react_button_has_type_config.deinit();
    try options.setByRuleConfigValue("react/button-has-type", react_button_has_type_config.value);
    try std.testing.expect(options.react_button_has_type);
    try std.testing.expect(options.react_button_has_type_button);
    try std.testing.expect(!options.react_button_has_type_submit);
    try std.testing.expect(!options.react_button_has_type_reset);

    var react_forbid_prop_types_config = try std.json.parseFromSlice(
        std.json.Value,
        std.testing.allocator,
        "[\"error\",{\"forbid\":[\"array\"]}]",
        .{},
    );
    defer react_forbid_prop_types_config.deinit();
    try options.setByRuleConfigValue("react/forbid-prop-types", react_forbid_prop_types_config.value);
    try std.testing.expect(options.react_forbid_prop_types);
    try std.testing.expect(!options.react_forbid_prop_types_forbid_any);
    try std.testing.expect(options.react_forbid_prop_types_forbid_array);
    try std.testing.expect(!options.react_forbid_prop_types_forbid_object);

    var react_default_props_match_prop_types_config = try std.json.parseFromSlice(
        std.json.Value,
        std.testing.allocator,
        "[\"error\",{\"allowRequiredDefaults\":true}]",
        .{},
    );
    defer react_default_props_match_prop_types_config.deinit();
    try options.setByRuleConfigValue("react/default-props-match-prop-types", react_default_props_match_prop_types_config.value);
    try std.testing.expect(options.react_default_props_match_prop_types);
    try std.testing.expect(options.react_default_props_match_prop_types_allow_required_defaults);

    var react_display_name_config = try std.json.parseFromSlice(
        std.json.Value,
        std.testing.allocator,
        "[\"error\",{\"checkContextObjects\":true}]",
        .{},
    );
    defer react_display_name_config.deinit();
    try options.setByRuleConfigValue("react/display-name", react_display_name_config.value);
    try std.testing.expect(options.react_display_name);
    try std.testing.expect(options.react_display_name_check_context_objects);

    var react_display_name_ignore_config = try std.json.parseFromSlice(
        std.json.Value,
        std.testing.allocator,
        "[\"error\",{\"ignoreTranspilerName\":true}]",
        .{},
    );
    defer react_display_name_ignore_config.deinit();
    try options.setByRuleConfigValue("react/display-name", react_display_name_ignore_config.value);
    try std.testing.expect(options.react_display_name);
    try std.testing.expect(options.react_display_name_ignore_transpiler_name);

    var react_jsx_filename_extension_config = try std.json.parseFromSlice(
        std.json.Value,
        std.testing.allocator,
        "[\"error\",{\"extensions\":[\".tsx\"]}]",
        .{},
    );
    defer react_jsx_filename_extension_config.deinit();
    try options.setByRuleConfigValue("react/jsx-filename-extension", react_jsx_filename_extension_config.value);
    try std.testing.expect(options.react_jsx_filename_extension);
    try std.testing.expectEqual(@as(usize, 1), options.react_jsx_filename_extension_extensions.len());
    try std.testing.expectEqualStrings(".tsx", options.react_jsx_filename_extension_extensions.at(0));

    var react_jsx_no_bind_config = try std.json.parseFromSlice(
        std.json.Value,
        std.testing.allocator,
        "[\"error\",{\"allowArrowFunctions\":true,\"allowFunctions\":true,\"allowBind\":true,\"ignoreRefs\":true,\"ignoreDOMComponents\":true}]",
        .{},
    );
    defer react_jsx_no_bind_config.deinit();
    try options.setByRuleConfigValue("react/jsx-no-bind", react_jsx_no_bind_config.value);
    try std.testing.expect(options.react_jsx_no_bind);
    try std.testing.expect(options.react_jsx_no_bind_allow_arrow_functions);
    try std.testing.expect(options.react_jsx_no_bind_allow_functions);
    try std.testing.expect(options.react_jsx_no_bind_allow_bind);
    try std.testing.expect(options.react_jsx_no_bind_ignore_refs);
    try std.testing.expect(options.react_jsx_no_bind_ignore_dom_components);

    var react_jsx_key_config = try std.json.parseFromSlice(
        std.json.Value,
        std.testing.allocator,
        "[\"error\",{\"checkKeyMustBeforeSpread\":true,\"checkFragmentShorthand\":true}]",
        .{},
    );
    defer react_jsx_key_config.deinit();
    try options.setByRuleConfigValue("react/jsx-key", react_jsx_key_config.value);
    try std.testing.expect(options.react_jsx_key);
    try std.testing.expect(options.react_jsx_key_check_key_must_before_spread);
    try std.testing.expect(options.react_jsx_key_check_fragment_shorthand);

    var react_jsx_no_target_blank_config = try std.json.parseFromSlice(
        std.json.Value,
        std.testing.allocator,
        "[\"error\",{\"allowReferrer\":true,\"enforceDynamicLinks\":\"never\"}]",
        .{},
    );
    defer react_jsx_no_target_blank_config.deinit();
    try options.setByRuleConfigValue("react/jsx-no-target-blank", react_jsx_no_target_blank_config.value);
    try std.testing.expect(options.react_jsx_no_target_blank);
    try std.testing.expect(options.react_jsx_no_target_blank_allow_referrer);
    try std.testing.expect(!options.react_jsx_no_target_blank_enforce_dynamic_links);

    var react_jsx_pascal_case_config = try std.json.parseFromSlice(
        std.json.Value,
        std.testing.allocator,
        "[\"error\",{\"allowAllCaps\":false,\"ignore\":[\"bar\",\"Legacy_widget\"]}]",
        .{},
    );
    defer react_jsx_pascal_case_config.deinit();
    try options.setByRuleConfigValue("react/jsx-pascal-case", react_jsx_pascal_case_config.value);
    try std.testing.expect(options.react_jsx_pascal_case);
    try std.testing.expect(!options.react_jsx_pascal_case_allow_all_caps);
    try std.testing.expect(options.react_jsx_pascal_case_ignore.contains("bar"));
    try std.testing.expect(options.react_jsx_pascal_case_ignore.contains("Legacy_widget"));
    try std.testing.expect(!options.react_jsx_pascal_case_ignore.contains("other"));

    var react_prop_types_config = try std.json.parseFromSlice(
        std.json.Value,
        std.testing.allocator,
        "[\"error\",{\"skipUndeclared\":true}]",
        .{},
    );
    defer react_prop_types_config.deinit();
    try options.setByRuleConfigValue("react/prop-types", react_prop_types_config.value);
    try std.testing.expect(options.react_prop_types);
    try std.testing.expect(options.react_prop_types_skip_undeclared);

    var react_no_string_refs_config = try std.json.parseFromSlice(
        std.json.Value,
        std.testing.allocator,
        "[\"error\",{\"noTemplateLiterals\":true}]",
        .{},
    );
    defer react_no_string_refs_config.deinit();
    try options.setByRuleConfigValue("react/no-string-refs", react_no_string_refs_config.value);
    try std.testing.expect(options.react_no_string_refs);
    try std.testing.expect(options.react_no_string_refs_no_template_literals);

    var react_no_multi_comp_config = try std.json.parseFromSlice(
        std.json.Value,
        std.testing.allocator,
        "[\"error\",{\"ignoreStateless\":false}]",
        .{},
    );
    defer react_no_multi_comp_config.deinit();
    try options.setByRuleConfigValue("react/no-multi-comp", react_no_multi_comp_config.value);
    try std.testing.expect(options.react_no_multi_comp);
    try std.testing.expect(!options.react_no_multi_comp_ignore_stateless);

    var react_no_unknown_property_config = try std.json.parseFromSlice(
        std.json.Value,
        std.testing.allocator,
        "[\"error\",{\"ignore\":[\"class\",\"data-Foo\"],\"requireDataLowercase\":true}]",
        .{},
    );
    defer react_no_unknown_property_config.deinit();
    try options.setByRuleConfigValue("react/no-unknown-property", react_no_unknown_property_config.value);
    try std.testing.expect(options.react_no_unknown_property);
    try std.testing.expect(options.react_no_unknown_property_ignore.contains("class"));
    try std.testing.expect(options.react_no_unknown_property_ignore.contains("data-Foo"));
    try std.testing.expect(!options.react_no_unknown_property_ignore.contains("other"));
    try std.testing.expect(options.react_no_unknown_property_require_data_lowercase);

    var react_self_closing_comp_config = try std.json.parseFromSlice(
        std.json.Value,
        std.testing.allocator,
        "[\"error\",{\"component\":false,\"html\":true}]",
        .{},
    );
    defer react_self_closing_comp_config.deinit();
    try options.setByRuleConfigValue("react/self-closing-comp", react_self_closing_comp_config.value);
    try std.testing.expect(options.react_self_closing_comp);
    try std.testing.expect(!options.react_self_closing_comp_component);
    try std.testing.expect(options.react_self_closing_comp_html);

    var react_no_unescaped_entities_config = try std.json.parseFromSlice(
        std.json.Value,
        std.testing.allocator,
        "[\"error\",{\"forbid\":[\">\",{\"char\":\"}\"}]}]",
        .{},
    );
    defer react_no_unescaped_entities_config.deinit();
    try options.setByRuleConfigValue("react/no-unescaped-entities", react_no_unescaped_entities_config.value);
    try std.testing.expect(options.react_no_unescaped_entities);
    try std.testing.expect(options.react_no_unescaped_entities_forbid_gt);
    try std.testing.expect(!options.react_no_unescaped_entities_forbid_double_quote);
    try std.testing.expect(!options.react_no_unescaped_entities_forbid_single_quote);
    try std.testing.expect(options.react_no_unescaped_entities_forbid_closing_brace);

    var react_prefer_es6_class_config = try std.json.parseFromSlice(
        std.json.Value,
        std.testing.allocator,
        "[\"error\",\"never\"]",
        .{},
    );
    defer react_prefer_es6_class_config.deinit();
    try options.setByRuleConfigValue("react/prefer-es6-class", react_prefer_es6_class_config.value);
    try std.testing.expect(options.react_prefer_es6_class);
    try std.testing.expectEqual(ReactPreferEs6ClassStyle.never, options.react_prefer_es6_class_style);

    var react_no_unused_prop_types_config = try std.json.parseFromSlice(
        std.json.Value,
        std.testing.allocator,
        "[\"error\",{\"skipShapeProps\":false}]",
        .{},
    );
    defer react_no_unused_prop_types_config.deinit();
    try options.setByRuleConfigValue("react/no-unused-prop-types", react_no_unused_prop_types_config.value);
    try std.testing.expect(options.react_no_unused_prop_types);
    try std.testing.expect(!options.react_no_unused_prop_types_skip_shape_props);

    var array_callback_return_config = try std.json.parseFromSlice(
        std.json.Value,
        std.testing.allocator,
        "[\"error\",{\"allowImplicit\":false,\"checkForEach\":true,\"allowVoid\":true}]",
        .{},
    );
    defer array_callback_return_config.deinit();
    try options.setByRuleConfigValue("array-callback-return", array_callback_return_config.value);
    try std.testing.expect(options.array_callback_return);
    try std.testing.expectEqual(ArrayCallbackReturnAllowImplicit.no, options.array_callback_return_allow_implicit);
    try std.testing.expectEqual(ArrayCallbackReturnCheckForEach.yes, options.array_callback_return_check_for_each);
    try std.testing.expectEqual(ArrayCallbackReturnAllowVoid.yes, options.array_callback_return_allow_void);

    var capitalized_comments_config = try std.json.parseFromSlice(
        std.json.Value,
        std.testing.allocator,
        "[\"error\",\"never\",{\"ignoreInlineComments\":true,\"ignoreConsecutiveComments\":true}]",
        .{},
    );
    defer capitalized_comments_config.deinit();
    try options.setByRuleConfigValue("capitalized-comments", capitalized_comments_config.value);
    try std.testing.expect(options.capitalized_comments);
    try std.testing.expectEqual(CapitalizedCommentsMode.never, options.capitalized_comments_mode);
    try std.testing.expectEqual(CapitalizedCommentsIgnoreInlineComments.yes, options.capitalized_comments_ignore_inline_comments);
    try std.testing.expectEqual(CapitalizedCommentsIgnoreConsecutiveComments.yes, options.capitalized_comments_ignore_consecutive_comments);

    var consistent_return_config = try std.json.parseFromSlice(
        std.json.Value,
        std.testing.allocator,
        "[\"error\",{\"treatUndefinedAsUnspecified\":true}]",
        .{},
    );
    defer consistent_return_config.deinit();
    try options.setByRuleConfigValue("consistent-return", consistent_return_config.value);
    try std.testing.expect(options.consistent_return);
    try std.testing.expect(options.consistent_return_treat_undefined_as_unspecified);

    var dot_notation_config = try std.json.parseFromSlice(
        std.json.Value,
        std.testing.allocator,
        "[\"error\",{\"allowKeywords\":false}]",
        .{},
    );
    defer dot_notation_config.deinit();
    try options.setByRuleConfigValue("dot-notation", dot_notation_config.value);
    try std.testing.expect(options.dot_notation);
    try std.testing.expectEqual(DotNotationAllowKeywords.no, options.dot_notation_allow_keywords);

    try options.setByRuleConfigValue("@typescript-eslint/dot-notation", .{ .string = "off" });
    try std.testing.expect(!options.typescript_eslint_dot_notation);
    try std.testing.expectEqual(DotNotationAllowKeywords.no, options.dot_notation_allow_keywords);

    var typescript_dot_notation_config = try std.json.parseFromSlice(
        std.json.Value,
        std.testing.allocator,
        "[\"error\",{\"allowKeywords\":true}]",
        .{},
    );
    defer typescript_dot_notation_config.deinit();
    try options.setByRuleConfigValue("@typescript-eslint/dot-notation", typescript_dot_notation_config.value);
    try std.testing.expect(options.typescript_eslint_dot_notation);
    try std.testing.expectEqual(DotNotationAllowKeywords.yes, options.dot_notation_allow_keywords);

    var curly_config = try std.json.parseFromSlice(
        std.json.Value,
        std.testing.allocator,
        "[\"error\",\"multi-line\"]",
        .{},
    );
    defer curly_config.deinit();
    try options.setByRuleConfigValue("curly", curly_config.value);
    try std.testing.expect(options.curly);
    try std.testing.expectEqual(CurlyStyle.multi_line, options.curly_style);

    var curly_multi_config = try std.json.parseFromSlice(
        std.json.Value,
        std.testing.allocator,
        "[\"error\",\"multi\"]",
        .{},
    );
    defer curly_multi_config.deinit();
    try options.setByRuleConfigValue("curly", curly_multi_config.value);
    try std.testing.expectEqual(CurlyStyle.multi, options.curly_style);

    var eqeqeq_config = try std.json.parseFromSlice(
        std.json.Value,
        std.testing.allocator,
        "[\"error\",\"allow-null\"]",
        .{},
    );
    defer eqeqeq_config.deinit();
    try options.setByRuleConfigValue("eqeqeq", eqeqeq_config.value);
    try std.testing.expect(options.eqeqeq);
    try std.testing.expectEqual(EqeqeqStyle.allow_null, options.eqeqeq_style);

    var eqeqeq_smart_config = try std.json.parseFromSlice(
        std.json.Value,
        std.testing.allocator,
        "[\"error\",\"smart\"]",
        .{},
    );
    defer eqeqeq_smart_config.deinit();
    try options.setByRuleConfigValue("eqeqeq", eqeqeq_smart_config.value);
    try std.testing.expectEqual(EqeqeqStyle.smart, options.eqeqeq_style);

    var accessor_pairs_config = try std.json.parseFromSlice(
        std.json.Value,
        std.testing.allocator,
        "[\"error\",{\"getWithoutSet\":true,\"setWithoutGet\":false,\"enforceForClassMembers\":false}]",
        .{},
    );
    defer accessor_pairs_config.deinit();
    try options.setByRuleConfigValue("accessor-pairs", accessor_pairs_config.value);
    try std.testing.expect(options.accessor_pairs);
    try std.testing.expectEqual(AccessorPairsGetWithoutSet.yes, options.accessor_pairs_get_without_set);
    try std.testing.expectEqual(AccessorPairsSetWithoutGet.no, options.accessor_pairs_set_without_get);
    try std.testing.expectEqual(AccessorPairsEnforceForClassMembers.no, options.accessor_pairs_enforce_for_class_members);

    var profile_a_config = try std.json.parseFromSlice(
        std.json.Value,
        std.testing.allocator,
        "[\"error\",{\"externalPackages\":{\"moment\":\"dayjs\"}}]",
        .{},
    );
    defer profile_a_config.deinit();
    try options.setByRuleConfigValue("@alipay/ant/no-deprecated-dependence", profile_a_config.value);
    try std.testing.expectEqual(DeprecatedDependenceProfile.profile_a, options.alipay_ant_no_deprecated_dependence_profile);

    var profile_b_config = try std.json.parseFromSlice(
        std.json.Value,
        std.testing.allocator,
        "[\"error\",{\"externalPackages\":{\"@example/bridge\":\"appkit\"}}]",
        .{},
    );
    defer profile_b_config.deinit();
    try options.setByRuleConfigValue("@alipay/ant/no-deprecated-dependence", profile_b_config.value);
    try std.testing.expectEqual(DeprecatedDependenceProfile.profile_b, options.alipay_ant_no_deprecated_dependence_profile);

    var restricted_disable_config = try std.json.parseFromSlice(
        std.json.Value,
        std.testing.allocator,
        "[\"warn\",\"no-nested-ternary\"]",
        .{},
    );
    defer restricted_disable_config.deinit();
    try options.setByRuleConfigValue("eslint-comments/no-restricted-disable", restricted_disable_config.value);
    try std.testing.expect(options.eslint_comments_no_restricted_disable);
    try std.testing.expect(options.eslint_comments_no_restricted_disable_no_nested_ternary);

    var func_name_matching_config = try std.json.parseFromSlice(
        std.json.Value,
        std.testing.allocator,
        "[\"error\",\"never\"]",
        .{},
    );
    defer func_name_matching_config.deinit();
    try options.setByRuleConfigValue("func-name-matching", func_name_matching_config.value);
    try std.testing.expect(options.func_name_matching);
    try std.testing.expectEqual(FuncNameMatchingStyle.never, options.func_name_matching_style);

    var func_names_config = try std.json.parseFromSlice(
        std.json.Value,
        std.testing.allocator,
        "[\"error\",\"never\",{\"generators\":\"as-needed\"}]",
        .{},
    );
    defer func_names_config.deinit();
    try options.setByRuleConfigValue("func-names", func_names_config.value);
    try std.testing.expect(options.func_names);
    try std.testing.expectEqual(FuncNamesStyle.never, options.func_names_style);
    try std.testing.expect(options.func_names_has_generator_style);
    try std.testing.expectEqual(FuncNamesStyle.as_needed, options.func_names_generator_style);

    var grouped_accessor_pairs_get_config = try std.json.parseFromSlice(
        std.json.Value,
        std.testing.allocator,
        "[\"error\",\"getBeforeSet\"]",
        .{},
    );
    defer grouped_accessor_pairs_get_config.deinit();
    try options.setByRuleConfigValue("grouped-accessor-pairs", grouped_accessor_pairs_get_config.value);
    try std.testing.expect(options.grouped_accessor_pairs);
    try std.testing.expectEqual(GroupedAccessorPairsStyle.get_before_set, options.grouped_accessor_pairs_style);

    var grouped_accessor_pairs_set_config = try std.json.parseFromSlice(
        std.json.Value,
        std.testing.allocator,
        "[\"error\",\"setBeforeGet\"]",
        .{},
    );
    defer grouped_accessor_pairs_set_config.deinit();
    try options.setByRuleConfigValue("grouped-accessor-pairs", grouped_accessor_pairs_set_config.value);
    try std.testing.expect(options.grouped_accessor_pairs);
    try std.testing.expectEqual(GroupedAccessorPairsStyle.set_before_get, options.grouped_accessor_pairs_style);

    var logical_assignment_operators_never_config = try std.json.parseFromSlice(
        std.json.Value,
        std.testing.allocator,
        "[\"error\",\"never\"]",
        .{},
    );
    defer logical_assignment_operators_never_config.deinit();
    try options.setByRuleConfigValue("logical-assignment-operators", logical_assignment_operators_never_config.value);
    try std.testing.expect(options.logical_assignment_operators);
    try std.testing.expectEqual(LogicalAssignmentOperatorsStyle.never, options.logical_assignment_operators_style);

    var logical_assignment_operators_if_config = try std.json.parseFromSlice(
        std.json.Value,
        std.testing.allocator,
        "[\"error\",\"always\",{\"enforceForIfStatements\":true}]",
        .{},
    );
    defer logical_assignment_operators_if_config.deinit();
    try options.setByRuleConfigValue("logical-assignment-operators", logical_assignment_operators_if_config.value);
    try std.testing.expect(options.logical_assignment_operators);
    try std.testing.expectEqual(LogicalAssignmentOperatorsStyle.always, options.logical_assignment_operators_style);
    try std.testing.expectEqual(
        LogicalAssignmentOperatorsEnforceForIfStatements.yes,
        options.logical_assignment_operators_enforce_for_if_statements,
    );

    var no_bitwise_config = try std.json.parseFromSlice(
        std.json.Value,
        std.testing.allocator,
        "[\"error\",{\"allow\":[\"|\",\"~\",\">>\"],\"int32Hint\":true}]",
        .{},
    );
    defer no_bitwise_config.deinit();
    try options.setByRuleConfigValue("no-bitwise", no_bitwise_config.value);
    try std.testing.expect(options.no_bitwise);
    try std.testing.expect(!options.no_bitwise_allow_bitwise_and);
    try std.testing.expect(options.no_bitwise_allow_bitwise_or);
    try std.testing.expect(!options.no_bitwise_allow_bitwise_xor);
    try std.testing.expect(options.no_bitwise_allow_bitwise_not);
    try std.testing.expect(!options.no_bitwise_allow_left_shift);
    try std.testing.expect(options.no_bitwise_allow_right_shift);
    try std.testing.expect(!options.no_bitwise_allow_unsigned_right_shift);
    try std.testing.expect(options.no_bitwise_int32_hint);

    var no_console_config = try std.json.parseFromSlice(
        std.json.Value,
        std.testing.allocator,
        "[\"error\",{\"allow\":[\"warn\",\"error\",\"todo\"]}]",
        .{},
    );
    defer no_console_config.deinit();
    try options.setByRuleConfigValue("no-console", no_console_config.value);
    try std.testing.expect(options.no_console);
    try std.testing.expect(options.no_console_allow.contains("warn"));
    try std.testing.expect(options.no_console_allow.contains("error"));
    try std.testing.expect(options.no_console_allow.contains("todo"));
    try std.testing.expect(!options.no_console_allow.contains("log"));

    var no_duplicate_imports_config = try std.json.parseFromSlice(
        std.json.Value,
        std.testing.allocator,
        "[\"error\",{\"allowSeparateTypeImports\":true}]",
        .{},
    );
    defer no_duplicate_imports_config.deinit();
    try options.setByRuleConfigValue("no-duplicate-imports", no_duplicate_imports_config.value);
    try std.testing.expect(options.no_duplicate_imports);
    try std.testing.expect(options.no_duplicate_imports_allow_separate_type_imports);

    var no_multi_assign_config = try std.json.parseFromSlice(
        std.json.Value,
        std.testing.allocator,
        "[\"error\",{\"ignoreNonDeclaration\":true}]",
        .{},
    );
    defer no_multi_assign_config.deinit();
    try options.setByRuleConfigValue("no-multi-assign", no_multi_assign_config.value);
    try std.testing.expect(options.no_multi_assign);
    try std.testing.expect(options.no_multi_assign_ignore_non_declaration);

    var no_cond_assign_config = try std.json.parseFromSlice(
        std.json.Value,
        std.testing.allocator,
        "[\"error\",\"always\"]",
        .{},
    );
    defer no_cond_assign_config.deinit();
    try options.setByRuleConfigValue("no-cond-assign", no_cond_assign_config.value);
    try std.testing.expect(options.no_cond_assign);
    try std.testing.expectEqual(NoCondAssignStyle.always, options.no_cond_assign_style);

    var no_constant_condition_config = try std.json.parseFromSlice(
        std.json.Value,
        std.testing.allocator,
        "[\"error\",{\"checkLoops\":\"none\"}]",
        .{},
    );
    defer no_constant_condition_config.deinit();
    try options.setByRuleConfigValue("no-constant-condition", no_constant_condition_config.value);
    try std.testing.expect(options.no_constant_condition);
    try std.testing.expectEqual(NoConstantConditionCheckLoops.none, options.no_constant_condition_check_loops);

    var no_constant_condition_false_config = try std.json.parseFromSlice(
        std.json.Value,
        std.testing.allocator,
        "[\"error\",{\"checkLoops\":false}]",
        .{},
    );
    defer no_constant_condition_false_config.deinit();
    try options.setByRuleConfigValue("no-constant-condition", no_constant_condition_false_config.value);
    try std.testing.expectEqual(NoConstantConditionCheckLoops.none, options.no_constant_condition_check_loops);

    var no_confusing_arrow_config = try std.json.parseFromSlice(
        std.json.Value,
        std.testing.allocator,
        "[\"error\",{\"allowParens\":false}]",
        .{},
    );
    defer no_confusing_arrow_config.deinit();
    try options.setByRuleConfigValue("no-confusing-arrow", no_confusing_arrow_config.value);
    try std.testing.expect(options.no_confusing_arrow);
    try std.testing.expectEqual(NoConfusingArrowAllowParens.no, options.no_confusing_arrow_allow_parens);

    var no_empty_config = try std.json.parseFromSlice(
        std.json.Value,
        std.testing.allocator,
        "[\"error\",{\"allowEmptyCatch\":true}]",
        .{},
    );
    defer no_empty_config.deinit();
    try options.setByRuleConfigValue("no-empty", no_empty_config.value);
    try std.testing.expect(options.no_empty);
    try std.testing.expectEqual(NoEmptyAllowEmptyCatch.yes, options.no_empty_allow_empty_catch);

    var no_eval_config = try std.json.parseFromSlice(
        std.json.Value,
        std.testing.allocator,
        "[\"error\",{\"allowIndirect\":true}]",
        .{},
    );
    defer no_eval_config.deinit();
    try options.setByRuleConfigValue("no-eval", no_eval_config.value);
    try std.testing.expect(options.no_eval);
    try std.testing.expect(options.no_eval_allow_indirect);

    var no_extend_native_config = try std.json.parseFromSlice(
        std.json.Value,
        std.testing.allocator,
        "[\"error\",{\"exceptions\":[\"Array\",\"Object\"]}]",
        .{},
    );
    defer no_extend_native_config.deinit();
    try options.setByRuleConfigValue("no-extend-native", no_extend_native_config.value);
    try std.testing.expect(options.no_extend_native);
    try std.testing.expect(options.no_extend_native_exceptions.contains("Array"));
    try std.testing.expect(options.no_extend_native_exceptions.contains("Object"));
    try std.testing.expect(!options.no_extend_native_exceptions.contains("String"));

    var no_global_assign_config = try std.json.parseFromSlice(
        std.json.Value,
        std.testing.allocator,
        "[\"error\",{\"exceptions\":[\"Object\",\"NaN\"]}]",
        .{},
    );
    defer no_global_assign_config.deinit();
    try options.setByRuleConfigValue("no-global-assign", no_global_assign_config.value);
    try std.testing.expect(options.no_global_assign);
    try std.testing.expect(options.no_global_assign_exceptions.contains("Object"));
    try std.testing.expect(options.no_global_assign_exceptions.contains("NaN"));
    try std.testing.expect(!options.no_global_assign_exceptions.contains("undefined"));

    var no_empty_function_config = try std.json.parseFromSlice(
        std.json.Value,
        std.testing.allocator,
        "[\"error\",{\"allow\":[\"functions\",\"constructors\"]}]",
        .{},
    );
    defer no_empty_function_config.deinit();
    try options.setByRuleConfigValue("no-empty-function", no_empty_function_config.value);
    try std.testing.expect(options.no_empty_function);
    try std.testing.expect(options.no_empty_function_allow.functions);
    try std.testing.expect(options.no_empty_function_allow.constructors);
    try std.testing.expect(!options.no_empty_function_allow.arrowFunctions);

    var no_empty_function_extended_config = try std.json.parseFromSlice(
        std.json.Value,
        std.testing.allocator,
        "[\"error\",{\"allow\":[\"asyncFunctions\",\"generatorFunctions\",\"asyncMethods\",\"generatorMethods\",\"getters\",\"setters\"]}]",
        .{},
    );
    defer no_empty_function_extended_config.deinit();
    try options.setByRuleConfigValue("no-empty-function", no_empty_function_extended_config.value);
    try std.testing.expect(options.no_empty_function_allow.asyncFunctions);
    try std.testing.expect(options.no_empty_function_allow.generatorFunctions);
    try std.testing.expect(options.no_empty_function_allow.asyncMethods);
    try std.testing.expect(options.no_empty_function_allow.generatorMethods);
    try std.testing.expect(options.no_empty_function_allow.getters);
    try std.testing.expect(options.no_empty_function_allow.setters);

    var typescript_no_empty_function_config = try std.json.parseFromSlice(
        std.json.Value,
        std.testing.allocator,
        "[\"error\",{\"allow\":[\"arrowFunctions\",\"methods\"]}]",
        .{},
    );
    defer typescript_no_empty_function_config.deinit();
    try options.setByRuleConfigValue("@typescript-eslint/no-empty-function", typescript_no_empty_function_config.value);
    try std.testing.expect(options.typescript_eslint_no_empty_function);
    try std.testing.expect(options.typescript_eslint_no_empty_function_allow.arrowFunctions);
    try std.testing.expect(options.typescript_eslint_no_empty_function_allow.methods);
    try std.testing.expect(!options.typescript_eslint_no_empty_function_allow.functions);

    var typescript_no_empty_interface_config = try std.json.parseFromSlice(
        std.json.Value,
        std.testing.allocator,
        "[\"error\",{\"allowSingleExtends\":true}]",
        .{},
    );
    defer typescript_no_empty_interface_config.deinit();
    try options.setByRuleConfigValue("@typescript-eslint/no-empty-interface", typescript_no_empty_interface_config.value);
    try std.testing.expect(options.typescript_eslint_no_empty_interface);
    try std.testing.expect(options.typescript_eslint_no_empty_interface_allow_single_extends);

    var no_else_return_config = try std.json.parseFromSlice(
        std.json.Value,
        std.testing.allocator,
        "[\"error\",{\"allowElseIf\":false}]",
        .{},
    );
    defer no_else_return_config.deinit();
    try options.setByRuleConfigValue("no-else-return", no_else_return_config.value);
    try std.testing.expect(options.no_else_return);
    try std.testing.expect(!options.no_else_return_allow_else_if);

    var no_empty_pattern_config = try std.json.parseFromSlice(
        std.json.Value,
        std.testing.allocator,
        "[\"error\",{\"allowObjectPatternsAsParameters\":true}]",
        .{},
    );
    defer no_empty_pattern_config.deinit();
    try options.setByRuleConfigValue("no-empty-pattern", no_empty_pattern_config.value);
    try std.testing.expect(options.no_empty_pattern);
    try std.testing.expect(options.no_empty_pattern_allow_object_patterns_as_parameters);

    var no_extra_boolean_cast_config = try std.json.parseFromSlice(
        std.json.Value,
        std.testing.allocator,
        "[\"error\",{\"enforceForInnerExpressions\":true}]",
        .{},
    );
    defer no_extra_boolean_cast_config.deinit();
    try options.setByRuleConfigValue("no-extra-boolean-cast", no_extra_boolean_cast_config.value);
    try std.testing.expect(options.no_extra_boolean_cast);
    try std.testing.expect(options.no_extra_boolean_cast_enforce_for_inner_expressions);

    var no_extra_boolean_cast_legacy_config = try std.json.parseFromSlice(
        std.json.Value,
        std.testing.allocator,
        "[\"error\",{\"enforceForLogicalOperands\":true}]",
        .{},
    );
    defer no_extra_boolean_cast_legacy_config.deinit();
    options.no_extra_boolean_cast_enforce_for_inner_expressions = false;
    try options.setByRuleConfigValue("no-extra-boolean-cast", no_extra_boolean_cast_legacy_config.value);
    try std.testing.expect(options.no_extra_boolean_cast);
    try std.testing.expect(options.no_extra_boolean_cast_enforce_for_inner_expressions);

    var no_extra_boolean_cast_precedence_config = try std.json.parseFromSlice(
        std.json.Value,
        std.testing.allocator,
        "[\"error\",{\"enforceForInnerExpressions\":false,\"enforceForLogicalOperands\":true}]",
        .{},
    );
    defer no_extra_boolean_cast_precedence_config.deinit();
    try options.setByRuleConfigValue("no-extra-boolean-cast", no_extra_boolean_cast_precedence_config.value);
    try std.testing.expect(!options.no_extra_boolean_cast_enforce_for_inner_expressions);

    var no_fallthrough_config = try std.json.parseFromSlice(
        std.json.Value,
        std.testing.allocator,
        "[\"error\",{\"allowEmptyCase\":true,\"commentPattern\":\"^ intentional fallthrough$\",\"reportUnusedFallthroughComment\":true}]",
        .{},
    );
    defer no_fallthrough_config.deinit();
    try options.setByRuleConfigValue("no-fallthrough", no_fallthrough_config.value);
    try std.testing.expect(options.no_fallthrough);
    try std.testing.expectEqual(NoFallthroughAllowEmptyCase.yes, options.no_fallthrough_allow_empty_case);
    try std.testing.expectEqualStrings(" intentional fallthrough", options.no_fallthrough_comment_pattern.pattern().?);
    try std.testing.expect(options.no_fallthrough_report_unused_fallthrough_comment);

    var no_implicit_coercion_config = try std.json.parseFromSlice(
        std.json.Value,
        std.testing.allocator,
        "[\"error\",{\"boolean\":false,\"number\":false,\"string\":true}]",
        .{},
    );
    defer no_implicit_coercion_config.deinit();
    try options.setByRuleConfigValue("no-implicit-coercion", no_implicit_coercion_config.value);
    try std.testing.expect(options.no_implicit_coercion);
    try std.testing.expectEqual(NoImplicitCoercionBoolean.no, options.no_implicit_coercion_boolean);
    try std.testing.expectEqual(NoImplicitCoercionNumber.no, options.no_implicit_coercion_number);
    try std.testing.expectEqual(NoImplicitCoercionString.yes, options.no_implicit_coercion_string);

    var no_implicit_coercion_allow_config = try std.json.parseFromSlice(
        std.json.Value,
        std.testing.allocator,
        "[\"error\",{\"allow\":[\"!!\",\"~\",\"+\",\"*\",\"-\",\"- -\"],\"disallowTemplateShorthand\":true}]",
        .{},
    );
    defer no_implicit_coercion_allow_config.deinit();
    try options.setByRuleConfigValue("no-implicit-coercion", no_implicit_coercion_allow_config.value);
    try std.testing.expect(options.no_implicit_coercion_allow_double_negation);
    try std.testing.expect(options.no_implicit_coercion_allow_bitwise_not);
    try std.testing.expect(options.no_implicit_coercion_allow_plus);
    try std.testing.expect(options.no_implicit_coercion_allow_multiply);
    try std.testing.expect(options.no_implicit_coercion_allow_subtract);
    try std.testing.expect(options.no_implicit_coercion_allow_double_negative);
    try std.testing.expect(options.no_implicit_coercion_disallow_template_shorthand);

    var no_inner_declarations_config = try std.json.parseFromSlice(
        std.json.Value,
        std.testing.allocator,
        "[\"error\",\"both\"]",
        .{},
    );
    defer no_inner_declarations_config.deinit();
    try options.setByRuleConfigValue("no-inner-declarations", no_inner_declarations_config.value);
    try std.testing.expect(options.no_inner_declarations);
    try std.testing.expectEqual(NoInnerDeclarationsMode.both, options.no_inner_declarations_mode);

    var no_labels_config = try std.json.parseFromSlice(
        std.json.Value,
        std.testing.allocator,
        "[\"error\",{\"allowLoop\":true,\"allowSwitch\":true}]",
        .{},
    );
    defer no_labels_config.deinit();
    try options.setByRuleConfigValue("no-labels", no_labels_config.value);
    try std.testing.expect(options.no_labels);
    try std.testing.expectEqual(NoLabelsAllowLoop.yes, options.no_labels_allow_loop);
    try std.testing.expectEqual(NoLabelsAllowSwitch.yes, options.no_labels_allow_switch);

    var new_cap_config = try std.json.parseFromSlice(
        std.json.Value,
        std.testing.allocator,
        "[\"error\",{\"newIsCap\":false,\"capIsNew\":false,\"properties\":false,\"newIsCapExceptions\":[\"lowerFactory\"],\"capIsNewExceptions\":[\"UpperFactory\"],\"newIsCapExceptionPattern\":\"^lower.*Factory$\",\"capIsNewExceptionPattern\":\"^Upper.*Factory$\"}]",
        .{},
    );
    defer new_cap_config.deinit();
    try options.setByRuleConfigValue("new-cap", new_cap_config.value);
    try std.testing.expect(options.new_cap);
    try std.testing.expect(!options.new_cap_new_is_cap);
    try std.testing.expect(!options.new_cap_cap_is_new);
    try std.testing.expect(!options.new_cap_properties);
    try std.testing.expect(options.new_cap_new_is_cap_exceptions.contains("lowerFactory"));
    try std.testing.expect(!options.new_cap_new_is_cap_exceptions.contains("otherFactory"));
    try std.testing.expect(options.new_cap_cap_is_new_exceptions.contains("UpperFactory"));
    try std.testing.expect(!options.new_cap_cap_is_new_exceptions.contains("OtherFactory"));
    try std.testing.expectEqualStrings("^lower.*Factory$", options.new_cap_new_is_cap_exception_pattern.pattern().?);
    try std.testing.expectEqualStrings("^Upper.*Factory$", options.new_cap_cap_is_new_exception_pattern.pattern().?);

    var no_multi_spaces_config = try std.json.parseFromSlice(
        std.json.Value,
        std.testing.allocator,
        "[\"error\",{\"ignoreEOLComments\":true,\"exceptions\":{\"Property\":false,\"BinaryExpression\":true,\"VariableDeclarator\":true,\"ImportDeclaration\":true}}]",
        .{},
    );
    defer no_multi_spaces_config.deinit();
    try options.setByRuleConfigValue("no-multi-spaces", no_multi_spaces_config.value);
    try std.testing.expect(options.no_multi_spaces);
    try std.testing.expectEqual(NoMultiSpacesIgnoreEOLComments.yes, options.no_multi_spaces_ignore_eol_comments);
    try std.testing.expect(!options.no_multi_spaces_exceptions.property);
    try std.testing.expect(options.no_multi_spaces_exceptions.binary_expression);
    try std.testing.expect(options.no_multi_spaces_exceptions.variable_declarator);
    try std.testing.expect(options.no_multi_spaces_exceptions.import_declaration);

    var no_multiple_empty_lines_config = try std.json.parseFromSlice(
        std.json.Value,
        std.testing.allocator,
        "[\"error\",{\"max\":1}]",
        .{},
    );
    defer no_multiple_empty_lines_config.deinit();
    try options.setByRuleConfigValue("no-multiple-empty-lines", no_multiple_empty_lines_config.value);
    try std.testing.expect(options.no_multiple_empty_lines);
    try std.testing.expectEqual(@as(usize, 1), options.no_multiple_empty_lines_max);
    try std.testing.expectEqual(@as(?usize, null), options.no_multiple_empty_lines_max_bof);
    try std.testing.expectEqual(@as(?usize, null), options.no_multiple_empty_lines_max_eof);

    var no_multiple_empty_lines_bof_config = try std.json.parseFromSlice(
        std.json.Value,
        std.testing.allocator,
        "[\"error\",{\"maxBOF\":0}]",
        .{},
    );
    defer no_multiple_empty_lines_bof_config.deinit();
    try options.setByRuleConfigValue("no-multiple-empty-lines", no_multiple_empty_lines_bof_config.value);
    try std.testing.expect(options.no_multiple_empty_lines);
    try std.testing.expectEqual(@as(usize, 2), options.no_multiple_empty_lines_max);
    try std.testing.expectEqual(@as(?usize, 0), options.no_multiple_empty_lines_max_bof);
    try std.testing.expectEqual(@as(?usize, null), options.no_multiple_empty_lines_max_eof);

    var no_multiple_empty_lines_eof_config = try std.json.parseFromSlice(
        std.json.Value,
        std.testing.allocator,
        "[\"error\",{\"maxEOF\":0}]",
        .{},
    );
    defer no_multiple_empty_lines_eof_config.deinit();
    try options.setByRuleConfigValue("no-multiple-empty-lines", no_multiple_empty_lines_eof_config.value);
    try std.testing.expect(options.no_multiple_empty_lines);
    try std.testing.expectEqual(@as(usize, 2), options.no_multiple_empty_lines_max);
    try std.testing.expectEqual(@as(?usize, null), options.no_multiple_empty_lines_max_bof);
    try std.testing.expectEqual(@as(?usize, 0), options.no_multiple_empty_lines_max_eof);

    var no_param_reassign_config = try std.json.parseFromSlice(
        std.json.Value,
        std.testing.allocator,
        "[\"error\",{\"props\":true,\"ignorePropertyModificationsFor\":[\"req\",\"res\"],\"ignorePropertyModificationsForRegex\":[\"^ctx\",\"Response$\"]}]",
        .{},
    );
    defer no_param_reassign_config.deinit();
    try options.setByRuleConfigValue("no-param-reassign", no_param_reassign_config.value);
    try std.testing.expect(options.no_param_reassign);
    try std.testing.expectEqual(NoParamReassignProps.yes, options.no_param_reassign_props);
    try std.testing.expect(options.no_param_reassign_ignore_property_modifications_for.contains("req"));
    try std.testing.expect(options.no_param_reassign_ignore_property_modifications_for.contains("res"));
    try std.testing.expect(!options.no_param_reassign_ignore_property_modifications_for.contains("ctx"));
    try std.testing.expectEqual(@as(usize, 2), options.no_param_reassign_ignore_property_modifications_for_regex.count);
    try std.testing.expectEqualStrings("^ctx", options.no_param_reassign_ignore_property_modifications_for_regex.at(0));
    try std.testing.expectEqualStrings("Response$", options.no_param_reassign_ignore_property_modifications_for_regex.at(1));

    var no_redeclare_config = try std.json.parseFromSlice(
        std.json.Value,
        std.testing.allocator,
        "[\"error\",{\"builtinGlobals\":true}]",
        .{},
    );
    defer no_redeclare_config.deinit();
    try options.setByRuleConfigValue("no-redeclare", no_redeclare_config.value);
    try std.testing.expect(options.no_redeclare);
    try std.testing.expectEqual(NoRedeclareBuiltinGlobals.yes, options.no_redeclare_builtin_globals);

    var typescript_no_redeclare_config = try std.json.parseFromSlice(
        std.json.Value,
        std.testing.allocator,
        "[\"error\",{\"builtinGlobals\":true,\"ignoreDeclarationMerge\":false}]",
        .{},
    );
    defer typescript_no_redeclare_config.deinit();
    try options.setByRuleConfigValue("@typescript-eslint/no-redeclare", typescript_no_redeclare_config.value);
    try std.testing.expect(options.typescript_eslint_no_redeclare);
    try std.testing.expect(options.typescript_eslint_no_redeclare_builtin_globals);
    try std.testing.expect(!options.typescript_eslint_no_redeclare_ignore_declaration_merge);

    var no_irregular_whitespace_config = try std.json.parseFromSlice(
        std.json.Value,
        std.testing.allocator,
        "[\"error\",{\"skipStrings\":false,\"skipComments\":true,\"skipRegExps\":true,\"skipTemplates\":true,\"skipJSXText\":true}]",
        .{},
    );
    defer no_irregular_whitespace_config.deinit();
    try options.setByRuleConfigValue("no-irregular-whitespace", no_irregular_whitespace_config.value);
    try std.testing.expect(options.no_irregular_whitespace);
    try std.testing.expect(!options.no_irregular_whitespace_skip_strings);
    try std.testing.expect(options.no_irregular_whitespace_skip_comments);
    try std.testing.expect(options.no_irregular_whitespace_skip_reg_exps);
    try std.testing.expect(options.no_irregular_whitespace_skip_templates);
    try std.testing.expect(options.no_irregular_whitespace_skip_jsx_text);

    var no_inline_comments_config = try std.json.parseFromSlice(
        std.json.Value,
        std.testing.allocator,
        "[\"error\",{\"ignorePattern\":\"eslint-disable|istanbul ignore\"}]",
        .{},
    );
    defer no_inline_comments_config.deinit();
    try options.setByRuleConfigValue("no-inline-comments", no_inline_comments_config.value);
    try std.testing.expect(options.no_inline_comments);
    try std.testing.expectEqualStrings("eslint-disable|istanbul ignore", options.no_inline_comments_ignore_pattern.pattern().?);

    var no_shadow_config = try std.json.parseFromSlice(
        std.json.Value,
        std.testing.allocator,
        "[\"error\",{\"allow\":[\"done\"],\"builtinGlobals\":true,\"hoist\":\"all\",\"ignoreOnInitialization\":true}]",
        .{},
    );
    defer no_shadow_config.deinit();
    try options.setByRuleConfigValue("no-shadow", no_shadow_config.value);
    try std.testing.expect(options.no_shadow);
    try std.testing.expect(options.no_shadow_allow.contains("done"));
    try std.testing.expect(!options.no_shadow_allow.contains("other"));
    try std.testing.expect(options.no_shadow_builtin_globals);
    try std.testing.expectEqual(NoShadowHoist.all, options.no_shadow_hoist);
    try std.testing.expect(options.no_shadow_ignore_on_initialization);

    var no_underscore_dangle_config = try std.json.parseFromSlice(
        std.json.Value,
        std.testing.allocator,
        "[\"error\",{\"allow\":[\"_allowed\"],\"allowAfterThis\":true,\"allowAfterSuper\":true,\"allowAfterThisConstructor\":true,\"allowFunctionParams\":false,\"allowInArrayDestructuring\":false,\"allowInObjectDestructuring\":false,\"enforceInMethodNames\":true,\"enforceInClassFields\":true}]",
        .{},
    );
    defer no_underscore_dangle_config.deinit();
    try options.setByRuleConfigValue("no-underscore-dangle", no_underscore_dangle_config.value);
    try std.testing.expect(options.no_underscore_dangle);
    try std.testing.expect(options.no_underscore_dangle_allow_after_this);
    try std.testing.expect(options.no_underscore_dangle_allow_after_super);
    try std.testing.expect(options.no_underscore_dangle_allow_after_this_constructor);
    try std.testing.expectEqual(NoUnderscoreDangleAllowFunctionParams.no, options.no_underscore_dangle_allow_function_params);
    try std.testing.expectEqual(NoUnderscoreDangleAllowDestructuring.no, options.no_underscore_dangle_allow_in_array_destructuring);
    try std.testing.expectEqual(NoUnderscoreDangleAllowDestructuring.no, options.no_underscore_dangle_allow_in_object_destructuring);
    try std.testing.expect(options.no_underscore_dangle_enforce_in_method_names);
    try std.testing.expect(options.no_underscore_dangle_enforce_in_class_fields);
    try std.testing.expect(options.no_underscore_dangle_allow.contains("_allowed"));
    try std.testing.expect(!options.no_underscore_dangle_allow.contains("_other"));

    var typescript_no_shadow_config = try std.json.parseFromSlice(
        std.json.Value,
        std.testing.allocator,
        "[\"error\",{\"allow\":[\"value\"],\"builtinGlobals\":true,\"hoist\":\"never\",\"ignoreOnInitialization\":true,\"ignoreTypeValueShadow\":true,\"ignoreFunctionTypeParameterNameValueShadow\":false}]",
        .{},
    );
    defer typescript_no_shadow_config.deinit();
    try options.setByRuleConfigValue("@typescript-eslint/no-shadow", typescript_no_shadow_config.value);
    try std.testing.expect(options.typescript_eslint_no_shadow);
    try std.testing.expect(options.typescript_eslint_no_shadow_allow.contains("value"));
    try std.testing.expect(!options.typescript_eslint_no_shadow_allow.contains("other"));
    try std.testing.expect(options.typescript_eslint_no_shadow_builtin_globals);
    try std.testing.expectEqual(NoShadowHoist.never, options.typescript_eslint_no_shadow_hoist);
    try std.testing.expect(options.typescript_eslint_no_shadow_ignore_on_initialization);
    try std.testing.expect(options.typescript_eslint_no_shadow_ignore_type_value_shadow);
    try std.testing.expect(!options.typescript_eslint_no_shadow_ignore_function_type_parameter_name_value_shadow);

    var no_plusplus_config = try std.json.parseFromSlice(
        std.json.Value,
        std.testing.allocator,
        "[\"error\",{\"allowForLoopAfterthoughts\":true}]",
        .{},
    );
    defer no_plusplus_config.deinit();
    try options.setByRuleConfigValue("no-plusplus", no_plusplus_config.value);
    try std.testing.expect(options.no_plusplus);
    try std.testing.expectEqual(NoPlusplusAllowForLoopAfterthoughts.yes, options.no_plusplus_allow_for_loop_afterthoughts);

    var object_shorthand_config = try std.json.parseFromSlice(
        std.json.Value,
        std.testing.allocator,
        "[\"error\",\"methods\",{\"avoidQuotes\":true,\"ignoreConstructors\":true}]",
        .{},
    );
    defer object_shorthand_config.deinit();
    try options.setByRuleConfigValue("object-shorthand", object_shorthand_config.value);
    try std.testing.expect(options.object_shorthand);
    try std.testing.expectEqual(ObjectShorthandStyle.methods, options.object_shorthand_style);
    try std.testing.expect(options.object_shorthand_avoid_quotes);
    try std.testing.expect(options.object_shorthand_ignore_constructors);

    var object_shorthand_arrows_config = try std.json.parseFromSlice(
        std.json.Value,
        std.testing.allocator,
        "[\"error\",\"always\",{\"avoidExplicitReturnArrows\":true}]",
        .{},
    );
    defer object_shorthand_arrows_config.deinit();
    try options.setByRuleConfigValue("object-shorthand", object_shorthand_arrows_config.value);
    try std.testing.expect(options.object_shorthand);
    try std.testing.expect(options.object_shorthand_avoid_explicit_return_arrows);

    var operator_assignment_config = try std.json.parseFromSlice(
        std.json.Value,
        std.testing.allocator,
        "[\"error\",\"never\"]",
        .{},
    );
    defer operator_assignment_config.deinit();
    try options.setByRuleConfigValue("operator-assignment", operator_assignment_config.value);
    try std.testing.expect(options.operator_assignment);
    try std.testing.expectEqual(OperatorAssignmentStyle.never, options.operator_assignment_style);

    var prefer_const_config = try std.json.parseFromSlice(
        std.json.Value,
        std.testing.allocator,
        "[\"error\",{\"destructuring\":\"all\",\"ignoreReadBeforeAssign\":false}]",
        .{},
    );
    defer prefer_const_config.deinit();
    try options.setByRuleConfigValue("prefer-const", prefer_const_config.value);
    try std.testing.expect(options.prefer_const);
    try std.testing.expectEqual(PreferConstDestructuring.all, options.prefer_const_destructuring);
    try std.testing.expect(!options.prefer_const_ignore_read_before_assign);

    var prefer_destructuring_config = try std.json.parseFromSlice(
        std.json.Value,
        std.testing.allocator,
        "[\"error\",{\"VariableDeclarator\":{\"array\":false,\"object\":true},\"AssignmentExpression\":{\"array\":true,\"object\":false}}]",
        .{},
    );
    defer prefer_destructuring_config.deinit();
    try options.setByRuleConfigValue("prefer-destructuring", prefer_destructuring_config.value);
    try std.testing.expect(options.prefer_destructuring);
    try std.testing.expect(!options.prefer_destructuring_variable_declarator_array);
    try std.testing.expect(options.prefer_destructuring_variable_declarator_object);
    try std.testing.expect(options.prefer_destructuring_assignment_expression_array);
    try std.testing.expect(!options.prefer_destructuring_assignment_expression_object);
    try std.testing.expect(!options.prefer_destructuring_enforce_for_renamed_properties);

    var prefer_destructuring_top_level_config = try std.json.parseFromSlice(
        std.json.Value,
        std.testing.allocator,
        "[\"error\",{\"array\":false,\"object\":true},{\"enforceForRenamedProperties\":true}]",
        .{},
    );
    defer prefer_destructuring_top_level_config.deinit();
    try options.setByRuleConfigValue("prefer-destructuring", prefer_destructuring_top_level_config.value);
    try std.testing.expect(!options.prefer_destructuring_variable_declarator_array);
    try std.testing.expect(options.prefer_destructuring_variable_declarator_object);
    try std.testing.expect(!options.prefer_destructuring_assignment_expression_array);
    try std.testing.expect(options.prefer_destructuring_assignment_expression_object);
    try std.testing.expect(options.prefer_destructuring_enforce_for_renamed_properties);

    var prefer_promise_reject_errors_config = try std.json.parseFromSlice(
        std.json.Value,
        std.testing.allocator,
        "[\"error\",{\"allowEmptyReject\":true}]",
        .{},
    );
    defer prefer_promise_reject_errors_config.deinit();
    try options.setByRuleConfigValue("prefer-promise-reject-errors", prefer_promise_reject_errors_config.value);
    try std.testing.expect(options.prefer_promise_reject_errors);
    try std.testing.expect(options.prefer_promise_reject_errors_allow_empty_reject);

    var no_promise_executor_return_config = try std.json.parseFromSlice(
        std.json.Value,
        std.testing.allocator,
        "[\"error\",{\"allowVoid\":true}]",
        .{},
    );
    defer no_promise_executor_return_config.deinit();
    try options.setByRuleConfigValue("no-promise-executor-return", no_promise_executor_return_config.value);
    try std.testing.expect(options.no_promise_executor_return);
    try std.testing.expect(options.no_promise_executor_return_allow_void);

    var prefer_regex_literals_config = try std.json.parseFromSlice(
        std.json.Value,
        std.testing.allocator,
        "[\"error\",{\"disallowRedundantWrapping\":true}]",
        .{},
    );
    defer prefer_regex_literals_config.deinit();
    try options.setByRuleConfigValue("prefer-regex-literals", prefer_regex_literals_config.value);
    try std.testing.expect(options.prefer_regex_literals);
    try std.testing.expect(options.prefer_regex_literals_disallow_redundant_wrapping);

    var radix_config = try std.json.parseFromSlice(
        std.json.Value,
        std.testing.allocator,
        "[\"error\",\"as-needed\"]",
        .{},
    );
    defer radix_config.deinit();
    try options.setByRuleConfigValue("radix", radix_config.value);
    try std.testing.expect(options.radix);
    try std.testing.expectEqual(RadixStyle.as_needed, options.radix_style);

    var require_atomic_updates_config = try std.json.parseFromSlice(
        std.json.Value,
        std.testing.allocator,
        "[\"error\",{\"allowProperties\":true}]",
        .{},
    );
    defer require_atomic_updates_config.deinit();
    try options.setByRuleConfigValue("require-atomic-updates", require_atomic_updates_config.value);
    try std.testing.expect(options.require_atomic_updates);
    try std.testing.expect(options.require_atomic_updates_allow_properties);

    var no_useless_rename_config = try std.json.parseFromSlice(
        std.json.Value,
        std.testing.allocator,
        "[\"error\",{\"ignoreDestructuring\":true,\"ignoreImport\":true,\"ignoreExport\":true}]",
        .{},
    );
    defer no_useless_rename_config.deinit();
    try options.setByRuleConfigValue("no-useless-rename", no_useless_rename_config.value);
    try std.testing.expect(options.no_useless_rename);
    try std.testing.expect(options.no_useless_rename_ignore_destructuring);
    try std.testing.expect(options.no_useless_rename_ignore_import);
    try std.testing.expect(options.no_useless_rename_ignore_export);

    var no_useless_escape_config = try std.json.parseFromSlice(
        std.json.Value,
        std.testing.allocator,
        "[\"error\",{\"allowRegexCharacters\":[\"#\",\"-\"]}]",
        .{},
    );
    defer no_useless_escape_config.deinit();
    try options.setByRuleConfigValue("no-useless-escape", no_useless_escape_config.value);
    try std.testing.expect(options.no_useless_escape);
    try std.testing.expect(options.no_useless_escape_allow_regex_characters.contains('#'));
    try std.testing.expect(options.no_useless_escape_allow_regex_characters.contains('-'));
    try std.testing.expect(!options.no_useless_escape_allow_regex_characters.contains('^'));

    var no_unsafe_negation_config = try std.json.parseFromSlice(
        std.json.Value,
        std.testing.allocator,
        "[\"error\",{\"enforceForOrderingRelations\":true}]",
        .{},
    );
    defer no_unsafe_negation_config.deinit();
    try options.setByRuleConfigValue("no-unsafe-negation", no_unsafe_negation_config.value);
    try std.testing.expect(options.no_unsafe_negation);
    try std.testing.expect(options.no_unsafe_negation_enforce_for_ordering_relations);

    var no_return_assign_config = try std.json.parseFromSlice(
        std.json.Value,
        std.testing.allocator,
        "[\"error\",\"always\"]",
        .{},
    );
    defer no_return_assign_config.deinit();
    try options.setByRuleConfigValue("no-return-assign", no_return_assign_config.value);
    try std.testing.expect(options.no_return_assign);
    try std.testing.expectEqual(NoReturnAssignStyle.always, options.no_return_assign_style);

    var no_sequences_config = try std.json.parseFromSlice(
        std.json.Value,
        std.testing.allocator,
        "[\"error\",{\"allowInParentheses\":false}]",
        .{},
    );
    defer no_sequences_config.deinit();
    try options.setByRuleConfigValue("no-sequences", no_sequences_config.value);
    try std.testing.expect(options.no_sequences);
    try std.testing.expectEqual(NoSequencesAllowInParentheses.no, options.no_sequences_allow_in_parentheses);

    var no_useless_computed_key_config = try std.json.parseFromSlice(
        std.json.Value,
        std.testing.allocator,
        "[\"error\",{\"enforceForClassMembers\":false}]",
        .{},
    );
    defer no_useless_computed_key_config.deinit();
    try options.setByRuleConfigValue("no-useless-computed-key", no_useless_computed_key_config.value);
    try std.testing.expect(options.no_useless_computed_key);
    try std.testing.expectEqual(
        NoUselessComputedKeyEnforceForClassMembers.no,
        options.no_useless_computed_key_enforce_for_class_members,
    );

    var no_unused_expressions_config = try std.json.parseFromSlice(
        std.json.Value,
        std.testing.allocator,
        "[\"error\",{\"allowShortCircuit\":true,\"allowTernary\":true,\"allowTaggedTemplates\":false}]",
        .{},
    );
    defer no_unused_expressions_config.deinit();
    try options.setByRuleConfigValue("no-unused-expressions", no_unused_expressions_config.value);
    try std.testing.expect(options.no_unused_expressions);
    try std.testing.expectEqual(NoUnusedExpressionsAllowShortCircuit.yes, options.no_unused_expressions_allow_short_circuit);
    try std.testing.expectEqual(NoUnusedExpressionsAllowTernary.yes, options.no_unused_expressions_allow_ternary);
    try std.testing.expectEqual(NoUnusedExpressionsAllowTaggedTemplates.no, options.no_unused_expressions_allow_tagged_templates);

    var no_unused_expressions_default_config = try std.json.parseFromSlice(
        std.json.Value,
        std.testing.allocator,
        "[\"error\"]",
        .{},
    );
    defer no_unused_expressions_default_config.deinit();
    try options.setByRuleConfigValue("no-unused-expressions", no_unused_expressions_default_config.value);
    try std.testing.expectEqual(NoUnusedExpressionsAllowTaggedTemplates.no, options.no_unused_expressions_allow_tagged_templates);

    var typescript_no_unused_expressions_config = try std.json.parseFromSlice(
        std.json.Value,
        std.testing.allocator,
        "[\"error\",{\"allowShortCircuit\":false,\"allowTernary\":false,\"allowTaggedTemplates\":false}]",
        .{},
    );
    defer typescript_no_unused_expressions_config.deinit();
    try options.setByRuleConfigValue("@typescript-eslint/no-unused-expressions", typescript_no_unused_expressions_config.value);
    try std.testing.expect(options.typescript_eslint_no_unused_expressions);
    try std.testing.expectEqual(NoUnusedExpressionsAllowShortCircuit.no, options.typescript_eslint_no_unused_expressions_allow_short_circuit);
    try std.testing.expectEqual(NoUnusedExpressionsAllowTernary.no, options.typescript_eslint_no_unused_expressions_allow_ternary);
    try std.testing.expectEqual(NoUnusedExpressionsAllowTaggedTemplates.no, options.typescript_eslint_no_unused_expressions_allow_tagged_templates);

    var no_unused_vars_config = try std.json.parseFromSlice(
        std.json.Value,
        std.testing.allocator,
        "[\"error\",{\"args\":\"all\",\"argsIgnorePattern\":\"^_\",\"caughtErrors\":\"none\",\"caughtErrorsIgnorePattern\":\"^ignoredError\",\"destructuredArrayIgnorePattern\":\"^ignoredItem\",\"ignoreClassWithStaticInitBlock\":true,\"ignoreRestSiblings\":true,\"ignoreUsingDeclarations\":true,\"reportUsedIgnorePattern\":true,\"varsIgnorePattern\":\"^ignored\"}]",
        .{},
    );
    defer no_unused_vars_config.deinit();
    try options.setByRuleConfigValue("no-unused-vars", no_unused_vars_config.value);
    try std.testing.expect(options.no_unused_vars);
    try std.testing.expectEqual(NoUnusedVarsVars.all, options.no_unused_vars_vars);
    try std.testing.expectEqual(NoUnusedVarsArgs.all, options.no_unused_vars_args);
    try std.testing.expectEqual(NoUnusedVarsCaughtErrors.none, options.no_unused_vars_caught_errors);
    try std.testing.expect(options.no_unused_vars_ignore_rest_siblings);
    try std.testing.expect(options.no_unused_vars_ignore_class_with_static_init_block);
    try std.testing.expect(options.no_unused_vars_ignore_using_declarations);
    try std.testing.expect(options.no_unused_vars_report_used_ignore_pattern);
    try std.testing.expectEqualStrings("^_", options.no_unused_vars_args_ignore_pattern.pattern().?);
    try std.testing.expectEqualStrings("^ignoredError", options.no_unused_vars_caught_errors_ignore_pattern.pattern().?);
    try std.testing.expectEqualStrings("^ignoredItem", options.no_unused_vars_destructured_array_ignore_pattern.pattern().?);
    try std.testing.expectEqualStrings("^ignored", options.no_unused_vars_vars_ignore_pattern.pattern().?);

    var typescript_no_unused_vars_config = try std.json.parseFromSlice(
        std.json.Value,
        std.testing.allocator,
        "[\"error\",{\"vars\":\"local\",\"args\":\"none\",\"argsIgnorePattern\":\"^unused\",\"caughtErrors\":\"none\",\"caughtErrorsIgnorePattern\":\"Error$\",\"destructuredArrayIgnorePattern\":\"Item$\",\"ignoreClassWithStaticInitBlock\":true,\"ignoreRestSiblings\":false,\"ignoreUsingDeclarations\":true,\"reportUsedIgnorePattern\":true,\"varsIgnorePattern\":\"Ignored$\"}]",
        .{},
    );
    defer typescript_no_unused_vars_config.deinit();
    try options.setByRuleConfigValue("@typescript-eslint/no-unused-vars", typescript_no_unused_vars_config.value);
    try std.testing.expect(options.typescript_eslint_no_unused_vars);
    try std.testing.expectEqual(NoUnusedVarsVars.local, options.typescript_eslint_no_unused_vars_vars);
    try std.testing.expectEqual(NoUnusedVarsArgs.none, options.typescript_eslint_no_unused_vars_args);
    try std.testing.expectEqual(NoUnusedVarsCaughtErrors.none, options.typescript_eslint_no_unused_vars_caught_errors);
    try std.testing.expect(!options.typescript_eslint_no_unused_vars_ignore_rest_siblings);
    try std.testing.expect(options.typescript_eslint_no_unused_vars_ignore_class_with_static_init_block);
    try std.testing.expect(options.typescript_eslint_no_unused_vars_ignore_using_declarations);
    try std.testing.expect(options.typescript_eslint_no_unused_vars_report_used_ignore_pattern);
    try std.testing.expectEqualStrings("^unused", options.typescript_eslint_no_unused_vars_args_ignore_pattern.pattern().?);
    try std.testing.expectEqualStrings("Error$", options.typescript_eslint_no_unused_vars_caught_errors_ignore_pattern.pattern().?);
    try std.testing.expectEqualStrings("Item$", options.typescript_eslint_no_unused_vars_destructured_array_ignore_pattern.pattern().?);
    try std.testing.expectEqualStrings("Ignored$", options.typescript_eslint_no_unused_vars_vars_ignore_pattern.pattern().?);

    var typescript_ban_types_config = try std.json.parseFromSlice(
        std.json.Value,
        std.testing.allocator,
        "[\"error\",{\"extendDefaults\":false,\"types\":{\"String\":false,\"object\":\"Use a named object shape.\",\"CustomType\":{\"message\":\"Use BetterType instead.\"}}}]",
        .{},
    );
    defer typescript_ban_types_config.deinit();
    try options.setByRuleConfigValue("@typescript-eslint/ban-types", typescript_ban_types_config.value);
    try std.testing.expect(options.typescript_eslint_ban_types);
    try std.testing.expect(!options.typescript_eslint_ban_types_config.extend_defaults);
    try std.testing.expect(options.typescript_eslint_ban_types_config.disabled.contains("String"));
    try std.testing.expectEqualStrings(
        "Use a named object shape.",
        options.typescript_eslint_ban_types_config.custom.messageFor("object") orelse "",
    );
    try std.testing.expectEqualStrings(
        "Use BetterType instead.",
        options.typescript_eslint_ban_types_config.custom.messageFor("CustomType") orelse "",
    );

    var typescript_consistent_type_assertions_config = try std.json.parseFromSlice(
        std.json.Value,
        std.testing.allocator,
        "[\"error\",{\"assertionStyle\":\"angle-bracket\",\"objectLiteralTypeAssertions\":\"allow-as-parameter\",\"arrayLiteralTypeAssertions\":\"never\"}]",
        .{},
    );
    defer typescript_consistent_type_assertions_config.deinit();
    try options.setByRuleConfigValue("@typescript-eslint/consistent-type-assertions", typescript_consistent_type_assertions_config.value);
    try std.testing.expect(options.typescript_eslint_consistent_type_assertions);
    try std.testing.expectEqual(
        TypescriptEslintConsistentTypeAssertionsStyle.angle_bracket,
        options.typescript_eslint_consistent_type_assertions_assertion_style,
    );
    try std.testing.expectEqual(
        TypescriptEslintLiteralTypeAssertions.allow_as_parameter,
        options.typescript_eslint_consistent_type_assertions_object_literal_type_assertions,
    );
    try std.testing.expectEqual(
        TypescriptEslintLiteralTypeAssertions.never,
        options.typescript_eslint_consistent_type_assertions_array_literal_type_assertions,
    );

    var typescript_explicit_member_accessibility_config = try std.json.parseFromSlice(
        std.json.Value,
        std.testing.allocator,
        "[\"error\",{\"accessibility\":\"explicit\"}]",
        .{},
    );
    defer typescript_explicit_member_accessibility_config.deinit();
    try options.setByRuleConfigValue("@typescript-eslint/explicit-member-accessibility", typescript_explicit_member_accessibility_config.value);
    try std.testing.expect(options.typescript_eslint_explicit_member_accessibility);
    try std.testing.expectEqual(
        TypescriptEslintExplicitMemberAccessibility.explicit,
        options.typescript_eslint_explicit_member_accessibility_accessibility,
    );

    var typescript_explicit_member_accessibility_off_config = try std.json.parseFromSlice(
        std.json.Value,
        std.testing.allocator,
        "[\"error\",{\"accessibility\":\"off\"}]",
        .{},
    );
    defer typescript_explicit_member_accessibility_off_config.deinit();
    try options.setByRuleConfigValue("@typescript-eslint/explicit-member-accessibility", typescript_explicit_member_accessibility_off_config.value);
    try std.testing.expectEqual(
        TypescriptEslintExplicitMemberAccessibility.off,
        options.typescript_eslint_explicit_member_accessibility_accessibility,
    );

    var typescript_no_inferrable_types_config = try std.json.parseFromSlice(
        std.json.Value,
        std.testing.allocator,
        "[\"error\",{\"ignoreParameters\":true,\"ignoreProperties\":true}]",
        .{},
    );
    defer typescript_no_inferrable_types_config.deinit();
    try options.setByRuleConfigValue("@typescript-eslint/no-inferrable-types", typescript_no_inferrable_types_config.value);
    try std.testing.expect(options.typescript_eslint_no_inferrable_types);
    try std.testing.expect(options.typescript_eslint_no_inferrable_types_ignore_parameters);
    try std.testing.expect(options.typescript_eslint_no_inferrable_types_ignore_properties);

    var typescript_no_invalid_void_type_config = try std.json.parseFromSlice(
        std.json.Value,
        std.testing.allocator,
        "[\"error\",{\"allowAsThisParameter\":true,\"allowInGenericTypeArguments\":false}]",
        .{},
    );
    defer typescript_no_invalid_void_type_config.deinit();
    try options.setByRuleConfigValue("@typescript-eslint/no-invalid-void-type", typescript_no_invalid_void_type_config.value);
    try std.testing.expect(options.typescript_eslint_no_invalid_void_type);
    try std.testing.expect(options.typescript_eslint_no_invalid_void_type_allow_as_this_parameter);
    try std.testing.expect(!options.typescript_eslint_no_invalid_void_type_allow_in_generic_type_arguments);

    var typescript_restrict_plus_operands_config = try std.json.parseFromSlice(
        std.json.Value,
        std.testing.allocator,
        "[\"error\",{\"allowNumberAndString\":true}]",
        .{},
    );
    defer typescript_restrict_plus_operands_config.deinit();
    try options.setByRuleConfigValue("@typescript-eslint/restrict-plus-operands", typescript_restrict_plus_operands_config.value);
    try std.testing.expect(options.typescript_eslint_restrict_plus_operands);
    try std.testing.expect(options.typescript_eslint_restrict_plus_operands_allow_number_and_string);

    var no_use_before_define_config = try std.json.parseFromSlice(
        std.json.Value,
        std.testing.allocator,
        "[\"error\",{\"functions\":false,\"classes\":false,\"variables\":false,\"allowNamedExports\":true}]",
        .{},
    );
    defer no_use_before_define_config.deinit();
    try options.setByRuleConfigValue("no-use-before-define", no_use_before_define_config.value);
    try std.testing.expect(options.no_use_before_define);
    try std.testing.expectEqual(NoUseBeforeDefineCheck.no, options.no_use_before_define_check_functions);
    try std.testing.expectEqual(NoUseBeforeDefineCheck.no, options.no_use_before_define_check_classes);
    try std.testing.expectEqual(NoUseBeforeDefineCheck.no, options.no_use_before_define_check_variables);
    try std.testing.expect(options.no_use_before_define_allow_named_exports);

    var no_use_before_define_nofunc_config = try std.json.parseFromSlice(
        std.json.Value,
        std.testing.allocator,
        "[\"error\",\"nofunc\"]",
        .{},
    );
    defer no_use_before_define_nofunc_config.deinit();
    try options.setByRuleConfigValue("no-use-before-define", no_use_before_define_nofunc_config.value);
    try std.testing.expectEqual(NoUseBeforeDefineCheck.no, options.no_use_before_define_check_functions);
    try std.testing.expectEqual(NoUseBeforeDefineCheck.yes, options.no_use_before_define_check_classes);
    try std.testing.expectEqual(NoUseBeforeDefineCheck.yes, options.no_use_before_define_check_variables);

    var no_undef_config = try std.json.parseFromSlice(
        std.json.Value,
        std.testing.allocator,
        "[\"error\",{\"typeof\":true}]",
        .{},
    );
    defer no_undef_config.deinit();
    try options.setByRuleConfigValue("no-undef", no_undef_config.value);
    try std.testing.expect(options.no_undef);
    try std.testing.expect(options.no_undef_typeof);

    var no_tabs_config = try std.json.parseFromSlice(
        std.json.Value,
        std.testing.allocator,
        "[\"error\",{\"allowIndentationTabs\":true}]",
        .{},
    );
    defer no_tabs_config.deinit();
    try options.setByRuleConfigValue("no-tabs", no_tabs_config.value);
    try std.testing.expect(options.no_tabs);
    try std.testing.expect(options.no_tabs_allow_indentation_tabs);

    var no_self_assign_config = try std.json.parseFromSlice(
        std.json.Value,
        std.testing.allocator,
        "[\"error\",{\"props\":false}]",
        .{},
    );
    defer no_self_assign_config.deinit();
    try options.setByRuleConfigValue("no-self-assign", no_self_assign_config.value);
    try std.testing.expect(options.no_self_assign);
    try std.testing.expect(!options.no_self_assign_props);

    var no_unneeded_ternary_config = try std.json.parseFromSlice(
        std.json.Value,
        std.testing.allocator,
        "[\"error\",{\"defaultAssignment\":false}]",
        .{},
    );
    defer no_unneeded_ternary_config.deinit();
    try options.setByRuleConfigValue("no-unneeded-ternary", no_unneeded_ternary_config.value);
    try std.testing.expect(options.no_unneeded_ternary);
    try std.testing.expect(!options.no_unneeded_ternary_default_assignment);

    var typescript_no_use_before_define_config = try std.json.parseFromSlice(
        std.json.Value,
        std.testing.allocator,
        "[\"error\",{\"functions\":true,\"classes\":false,\"variables\":false,\"typedefs\":false,\"enums\":false,\"allowNamedExports\":true,\"ignoreTypeReferences\":false}]",
        .{},
    );
    defer typescript_no_use_before_define_config.deinit();
    try options.setByRuleConfigValue("@typescript-eslint/no-use-before-define", typescript_no_use_before_define_config.value);
    try std.testing.expect(options.typescript_eslint_no_use_before_define);
    try std.testing.expectEqual(NoUseBeforeDefineCheck.yes, options.typescript_eslint_no_use_before_define_check_functions);
    try std.testing.expectEqual(NoUseBeforeDefineCheck.no, options.typescript_eslint_no_use_before_define_check_classes);
    try std.testing.expectEqual(NoUseBeforeDefineCheck.no, options.typescript_eslint_no_use_before_define_check_variables);
    try std.testing.expectEqual(NoUseBeforeDefineCheck.no, options.typescript_eslint_no_use_before_define_check_typedefs);
    try std.testing.expectEqual(NoUseBeforeDefineCheck.no, options.typescript_eslint_no_use_before_define_check_enums);
    try std.testing.expect(options.typescript_eslint_no_use_before_define_allow_named_exports);
    try std.testing.expect(!options.typescript_eslint_no_use_before_define_ignore_type_references);

    var no_void_config = try std.json.parseFromSlice(
        std.json.Value,
        std.testing.allocator,
        "[\"error\",{\"allowAsStatement\":true}]",
        .{},
    );
    defer no_void_config.deinit();
    try options.setByRuleConfigValue("no-void", no_void_config.value);
    try std.testing.expect(options.no_void);
    try std.testing.expectEqual(NoVoidAllowAsStatement.yes, options.no_void_allow_as_statement);

    var no_warning_comments_config = try std.json.parseFromSlice(
        std.json.Value,
        std.testing.allocator,
        "[\"error\",{\"terms\":[\"review\",\"blocked by upstream\"],\"location\":\"anywhere\",\"decoration\":[\"/\",\"*\"]}]",
        .{},
    );
    defer no_warning_comments_config.deinit();
    try options.setByRuleConfigValue("no-warning-comments", no_warning_comments_config.value);
    try std.testing.expect(options.no_warning_comments);
    try std.testing.expectEqual(NoWarningCommentsLocation.anywhere, options.no_warning_comments_location);
    try std.testing.expectEqual(NoWarningCommentsDecoration.slash_asterisk, options.no_warning_comments_decoration);
    try std.testing.expectEqual(@as(usize, 2), options.no_warning_comments_terms.len());
    try std.testing.expectEqualStrings("review", options.no_warning_comments_terms.at(0));
    try std.testing.expectEqualStrings("blocked by upstream", options.no_warning_comments_terms.at(1));

    var valid_typeof_config = try std.json.parseFromSlice(
        std.json.Value,
        std.testing.allocator,
        "[\"error\",{\"requireStringLiterals\":true}]",
        .{},
    );
    defer valid_typeof_config.deinit();
    try options.setByRuleConfigValue("valid-typeof", valid_typeof_config.value);
    try std.testing.expect(options.valid_typeof);
    try std.testing.expect(options.valid_typeof_require_string_literals);

    var spaced_comment_config = try std.json.parseFromSlice(
        std.json.Value,
        std.testing.allocator,
        "[\"error\",\"never\",{\"markers\":[\"/\",\"!\"],\"exceptions\":[\"-\",\"+\"]}]",
        .{},
    );
    defer spaced_comment_config.deinit();
    try options.setByRuleConfigValue("spaced-comment", spaced_comment_config.value);
    try std.testing.expect(options.spaced_comment);
    try std.testing.expectEqual(SpacedCommentStyle.never, options.spaced_comment_style);
    try std.testing.expect(options.spaced_comment_markers.matches("/ reference"));
    try std.testing.expect(options.spaced_comment_markers.matches("! license"));
    try std.testing.expect(!options.spaced_comment_markers.matches("# plain"));
    try std.testing.expect(options.spaced_comment_exceptions.matches("- separator"));
    try std.testing.expect(options.spaced_comment_exceptions.matches("+ separator"));
    try std.testing.expect(!options.spaced_comment_exceptions.matches("# plain"));

    var wrap_iife_config = try std.json.parseFromSlice(
        std.json.Value,
        std.testing.allocator,
        "[\"error\",\"inside\"]",
        .{},
    );
    defer wrap_iife_config.deinit();
    try options.setByRuleConfigValue("wrap-iife", wrap_iife_config.value);
    try std.testing.expect(options.wrap_iife);
    try std.testing.expectEqual(WrapIifeStyle.inside, options.wrap_iife_style);

    var yoda_config = try std.json.parseFromSlice(
        std.json.Value,
        std.testing.allocator,
        "[\"error\",\"always\"]",
        .{},
    );
    defer yoda_config.deinit();
    try options.setByRuleConfigValue("yoda", yoda_config.value);
    try std.testing.expect(options.yoda);
    try std.testing.expectEqual(YodaStyle.always, options.yoda_style);

    var yoda_only_equality_config = try std.json.parseFromSlice(
        std.json.Value,
        std.testing.allocator,
        "[\"error\",\"never\",{\"onlyEquality\":true}]",
        .{},
    );
    defer yoda_only_equality_config.deinit();
    try options.setByRuleConfigValue("yoda", yoda_only_equality_config.value);
    try std.testing.expectEqual(YodaStyle.never, options.yoda_style);
    try std.testing.expect(options.yoda_only_equality);

    try std.testing.expectError(
        Options.RuleConfigError.UnsupportedRuleConfigValue,
        options.setByRuleConfigValue("no-debugger", .{ .string = "sometimes" }),
    );
    try std.testing.expectError(
        Options.RuleConfigError.UnknownRule,
        options.setByRuleConfigValue("unknown-rule", .{ .string = "off" }),
    );
}
