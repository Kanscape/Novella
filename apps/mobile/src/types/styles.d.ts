declare module '*.css';

declare module '*.svg' {
  import type { ComponentType } from 'react';
  import type { SvgProps } from 'react-native-svg';

  const content: ComponentType<SvgProps>;
  export default content;
}
