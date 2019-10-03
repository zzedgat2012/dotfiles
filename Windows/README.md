# Here I store some useful commands for Windows environments 

For contact see my personal blog at [try-eddy](https://try-eddy.8sistemas.com/) :computer:

## Use DISM to fix issues SFC can't

*For more information about this command see: https://bre.is/VuzjxD6d*

DISM can be run in dry-mode to reveal corruption without attempting to fix issues found. I recommend that you check the health first to find out if corruption exists before you run repair operations.

**DISM /Online /Cleanup-Image /RestoreHealth**
