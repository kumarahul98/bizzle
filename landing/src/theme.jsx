import React from 'react'

export const ThemeCtx = React.createContext(null)
export function useTheme() { return React.useContext(ThemeCtx) }
