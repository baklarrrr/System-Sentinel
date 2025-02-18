# -*- mode: python ; coding: utf-8 -*-


a = Analysis(
    ['SystemSentinelGUI.py'],
    pathex=[],
    binaries=[],
    datas=[('SystemSentinel.ps1', '.'), ('SystemSentinelModule.psm1', '.'), ('SystemSentinelConfig.json', '.'), ('SystemSentinel.ico', '.')],
    hiddenimports=['os', 'sys'],
    hookspath=[],
    hooksconfig={},
    runtime_hooks=[],
    excludes=[],
    noarchive=False,
    optimize=0,
)
pyz = PYZ(a.pure)

exe = EXE(
    pyz,
    a.scripts,
    a.binaries,
    a.datas,
    [],
    name='SystemSentinelGUI',
    debug=False,
    bootloader_ignore_signals=False,
    strip=False,
    upx=True,
    upx_exclude=[],
    runtime_tmpdir=None,
    console=True,
    disable_windowed_traceback=False,
    argv_emulation=False,
    target_arch=None,
    codesign_identity=None,
    entitlements_file=None,
    icon=['SystemSentinel.ico'],
)
