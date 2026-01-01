# GitHub Copilot Instructions for OM Module

## MANDATORY RULES

1. **ALWAYS read the actual implementation code before suggesting any command or code**
   - Use `read_file` to check the actual implementation
   - Cite specific line numbers when referencing code
   - Never guess based on "typical" patterns

2. **NEVER provide PowerShell commands without verifying how they work in THIS codebase**
   - Read Set-OMTags, Get-OMTags, and other functions before suggesting their use
   - Test your understanding by reading the code first

3. **If you don't know, investigate first - don't guess**
   - Use semantic_search or grep_search to find relevant code
   - Read the implementation files
   - Only then provide an answer

4. **Arrays in PowerShell are critical**
   - Always check if properties are arrays or strings
   - Always use `@()` to ensure array type when needed

## About This Module

- OM is a PowerShell module for audio file tagging
- Uses TagLib-Sharp library
- Key functions: Get-OMTags, Set-OMTags, Start-OM
- Genre handling is critical - genres must be arrays