import {defineConfig} from 'vite';
export default defineConfig({root:'apps/web',base:'./',define:{'process.env.NODE_ENV':JSON.stringify('production')},build:{lib:{entry:'src/main.tsx',name:'MemoryCatcher',formats:['iife'],fileName:()=> 'app.js',cssFileName:'app'},outDir:'dist',emptyOutDir:true},server:{host:'127.0.0.1',port:8445,strictPort:true}});
