// tailwind.config.mjs
export default {
  content: ['./src/**/*.{astro,html,js,ts}'],
  theme: {
    extend: {
      colors: {
        navy:       '#0d1f3c',
        'baby-blue':'#4a90c4',
        'pale-blue':'#e8f2f9',
        gold:       '#c9a84c',
        cream:      '#f7f9fc',
      },
      fontFamily: {
        nunito: ['Nunito', 'sans-serif'],
      },
    },
  },
};