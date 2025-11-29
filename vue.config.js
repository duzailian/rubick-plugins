const { defineConfig } = require('@vue/cli-service')

module.exports = defineConfig({
  transpileDependencies: true,
  publicPath: './',
  outputDir: 'dist',
  assetsDir: 'static',
  indexPath: 'index.html',
  devServer: {
    port: 4001,
    host: 'localhost'
  },
  configureWebpack: {
    externals: {
      // 将 marked 外部化，因为我们在 App.vue 中直接引入了
      'marked': 'marked'
    },
    // 完全禁用 source maps
    devtool: false
  },
  // 生产环境配置
  productionSourceMap: false, // 禁用 source maps
  chainWebpack: config => {
    // 完全禁用所有 source maps
    config.devtool(false)

    // 优化构建
    config.optimization.minimize(true)

    // 处理静态资源
    config.module
      .rule('images')
      .test(/\.(png|jpe?g|gif|webp|svg)(\?.*)?$/)
      .use('url-loader')
      .loader('url-loader')
      .options({
        limit: 4096,
        fallback: {
          loader: 'file-loader',
          options: {
            name: 'static/img/[name].[hash:8].[ext]'
          }
        }
      })
  }
})
