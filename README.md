# VendorTrashManager

Originally designed for wow-classic

All grey items with a vendor price are automatically sold when you open a merchant window.


## additional configuration:

If you want to prevent a grey item from being sold, run slash command:

```shell
/vtm keep <itemlink>
```

If you want to automatically sell a non-grey item, run slash command:

```shell
/vtm sell <itemlink>
```

This sell command is very useful when farming dungeons for gold!

If you want to undo a command, `sell` and `keep` are opposites of eachother.


## debug info

```shell
/vtm debug <itemlink>
```

Will display information such as the item's ID, SellPrice, if it is grey or not, and if the item would be automatically sold.
