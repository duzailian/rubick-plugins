<template>
  <div id="app">
    <div class="search-container" v-show="!showDetail">
      <input
        type="text"
        v-model="keyword"
        placeholder="输入命令搜索 (例如: ls, tar, grep)..."
        ref="searchInput"
        @input="handleSearch"
      >
    </div>

    <div class="list-container" v-show="!showDetail">
      <div v-if="loading" style="text-align:center; padding: 20px; color:#999;">加载数据中...</div>
      <div v-else-if="filteredCommands.length === 0" style="text-align:center; padding: 20px; color:#999;">未找到相关命令</div>

      <div
        class="command-item"
        v-for="cmd in filteredCommands"
        :key="cmd.n"
        @click="viewDetail(cmd.n)"
      >
        <div class="cmd-name">{{ cmd.n }}</div>
        <div class="cmd-desc">{{ cmd.d }}</div>
      </div>
    </div>

    <div class="detail-container" :class="{ show: showDetail }">
      <div class="back-btn" @click="goBack">← 返回搜索列表</div>
      <div class="markdown-body" v-html="detailHtml"></div>
      <div v-if="detailLoading" style="text-align:center; padding: 50px;">详情加载中...</div>
    </div>
  </div>
</template>

<script>
import { marked } from 'marked'

export default {
  name: 'App',
  data() {
    return {
      allCommands: {}, // 原始数据对象
      commandList: [], // 转换后的数组格式
      keyword: '',
      filteredCommands: [],
      showDetail: false,
      detailHtml: '',
      detailLoading: false,
      loading: true,
      debugMode: false,
      errorCount: 0
    }
  },
  mounted() {
    // 初始化调试信息
    this.initDebug();

    this.initData();
    // 自动聚焦输入框
    this.$nextTick(() => {
      if(this.$refs.searchInput) this.$refs.searchInput.focus();
    });

    // 监听键盘事件
    document.addEventListener('keydown', this.handleKeydown);

    // 监听 Rubick 事件
    if (window.rubick) {
      window.rubick.onPluginEnter(({ type, payload }) => {
        // 如果用户带参数进入，例如 "linux ls"
        if (type === 'text' && payload) {
          this.keyword = payload;
          this.handleSearch();
        }
        this.$refs.searchInput.focus();
      });
    }
  },
  beforeUnmount() {
    // 清理事件监听器
    document.removeEventListener('keydown', this.handleKeydown);
  },
  methods: {
    // 初始化调试工具
    initDebug() {
      if (window.pluginDebug) {
        this.debugMode = window.pluginDebug.isDev;
        window.pluginDebug.debug.log('Debug tools initialized');
      }
    },

    // 错误处理包装器
    safeExecute(name, fn, context = {}) {
      try {
        if (window.pluginDebug) {
          return window.pluginDebug.performanceMonitor.measure(name, fn);
        }
        return fn();
      } catch (error) {
        this.errorCount++;
        if (window.pluginDebug) {
          window.pluginDebug.errorTracker.track(error, {
            method: name,
            ...context
          });
          window.pluginDebug.debug.error(`Error in ${name}:`, error);
        } else {
          console.error(`Error in ${name}:`, error);
        }
        throw error;
      }
    },

    async initData() {
      try {
        // 尝试从 localStorage 读取缓存
        const cache = localStorage.getItem('linux_cmd_data');
        const cacheTimestamp = localStorage.getItem('linux_cmd_data_timestamp');
        const isCacheValid = cacheTimestamp && (Date.now() - parseInt(cacheTimestamp)) < 24 * 60 * 60 * 1000; // 24小时缓存

        if (cache && isCacheValid) {
          this.allCommands = JSON.parse(cache);
          this.processData();
          this.loading = false;
        }

        // 无论是否有缓存，都在后台更新一次数据 (Stale-while-revalidate 策略)
        try {
          const res = await fetch('https://unpkg.com/linux-command@latest/dist/data.json');
          if (!res.ok) throw new Error(`HTTP ${res.status}`);
          const data = await res.json();
          this.allCommands = data;
          localStorage.setItem('linux_cmd_data', JSON.stringify(data));
          localStorage.setItem('linux_cmd_data_timestamp', Date.now().toString());

          if (!cache || !isCacheValid) {
            this.processData();
            this.loading = false;
          }
        } catch (fetchError) {
          console.error('网络数据加载失败，使用缓存数据', fetchError);
          // 如果网络失败但有缓存，使用缓存
          if (cache && !this.commandList.length) {
            this.allCommands = JSON.parse(cache);
            this.processData();
            this.loading = false;
          } else if (!this.commandList.length) {
            throw fetchError;
          }
        }
      } catch (e) {
        console.error('加载数据失败', e);
        this.loading = false;
        if(!this.commandList.length) {
          this.detailHtml = '<h3>加载数据失败，请检查网络连接。</h3>';
        }
      }
    },
    processData() {
      // data.json 结构通常为 { "ls": { "n": "ls", "d": "描述", ... }, ... }
      this.commandList = Object.values(this.allCommands);
      this.filteredCommands = this.commandList;
    },
    handleSearch() {
      const k = this.keyword.toLowerCase().trim();
      if (!k) {
        this.filteredCommands = this.commandList;
        return;
      }

      // 改进搜索：优先匹配命令名，然后匹配描述
      this.filteredCommands = this.commandList.filter(item => {
        if (!item.n && !item.d) return false;

        const nameMatch = item.n && item.n.toLowerCase().includes(k);
        const descMatch = item.d && item.d.toLowerCase().includes(k);

        return nameMatch || descMatch;
      }).sort((a, b) => {
        // 优先显示命令名完全匹配的结果
        const aNameExact = a.n && a.n.toLowerCase() === k;
        const bNameExact = b.n && b.n.toLowerCase() === k;

        if (aNameExact && !bNameExact) return -1;
        if (!aNameExact && bNameExact) return 1;

        // 然后按命令名匹配程度排序
        const aNameStartsWith = a.n && a.n.toLowerCase().startsWith(k);
        const bNameStartsWith = b.n && b.n.toLowerCase().startsWith(k);

        if (aNameStartsWith && !bNameStartsWith) return -1;
        if (!aNameStartsWith && bNameStartsWith) return 1;

        return 0;
      });
    },
    async viewDetail(cmdName) {
      this.showDetail = true;
      this.detailLoading = true;
      this.detailHtml = '';

      try {
        // 获取 Markdown
        const res = await fetch(`https://raw.githubusercontent.com/jaywcjlove/linux-command/master/command/${cmdName}.md`);
        if (!res.ok) throw new Error('Not found');
        const text = await res.text();

        // 渲染 Markdown
        this.detailHtml = marked.parse(text);
      } catch (e) {
        this.detailHtml = '<h3>加载详情失败或命令文档不存在。</h3>';
      } finally {
        this.detailLoading = false;
      }
    },
    handleKeydown(event) {
      // 只在搜索列表页面处理键盘导航
      if (this.showDetail) {
        // 在详情页面，ESC 键返回
        if (event.key === 'Escape') {
          this.goBack();
          event.preventDefault();
        }
        return;
      }

      // 在搜索列表页面的键盘导航
      switch (event.key) {
        case 'ArrowDown':
          // 向下选择下一个命令
          event.preventDefault();
          break;
        case 'ArrowUp':
          // 向上选择上一个命令
          event.preventDefault();
          break;
        case 'Enter':
          // 如果搜索结果只有一个，直接打开
          if (this.filteredCommands.length === 1) {
            this.viewDetail(this.filteredCommands[0].n);
            event.preventDefault();
          }
          break;
        case 'Escape':
          // 清空搜索框
          this.keyword = '';
          this.handleSearch();
          event.preventDefault();
          break;
      }
    },
    goBack() {
      this.showDetail = false;
      this.$nextTick(() => {
        this.$refs.searchInput.focus();
      });
    }
  }
}
</script>

<style>
body { margin: 0; padding: 0; font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Helvetica Neue", Arial, sans-serif; background-color: #f5f5f5; color: #333; }
#app { display: flex; flex-direction: column; height: 100vh; }

/* 搜索栏样式 */
.search-container { padding: 10px; background: #fff; box-shadow: 0 2px 4px rgba(0,0,0,0.1); position: sticky; top: 0; z-index: 10; }
input { width: 100%; padding: 10px; font-size: 16px; border: 1px solid #ddd; border-radius: 4px; box-sizing: border-box; outline: none; }
input:focus { border-color: #007bff; }

/* 列表区域 */
.list-container { flex: 1; overflow-y: auto; padding: 10px; }
.command-item { background: #fff; padding: 10px; margin-bottom: 8px; border-radius: 4px; cursor: pointer; transition: background 0.2s; border-left: 4px solid transparent; }
.command-item:hover { background: #e9ecef; }
.command-item.active { border-left-color: #007bff; background: #f0f4ff; }
.cmd-name { font-weight: bold; font-size: 18px; color: #007bff; }
.cmd-desc { color: #666; font-size: 14px; margin-top: 4px; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }

/* 详情区域 (模态框或覆盖层) */
.detail-container { position: fixed; top: 0; left: 0; width: 100%; height: 100%; background: #fff; overflow-y: auto; display: none; padding: 20px; box-sizing: border-box; z-index: 20; }
.detail-container.show { display: block; animation: slideIn 0.2s ease-out; }
.back-btn { display: inline-block; margin-bottom: 20px; padding: 8px 16px; background: #007bff; color: #fff; border-radius: 4px; cursor: pointer; font-size: 14px; user-select: none; }
.back-btn:hover { background: #0056b3; }

/* Markdown 样式微调 */
.markdown-body { font-size: 15px; line-height: 1.6; max-width: 800px; margin: 0 auto; }
.markdown-body pre { background: #f6f8fa; padding: 16px; border-radius: 4px; overflow-x: auto; }
.markdown-body code { background: rgba(27,31,35,.05); padding: .2em .4em; border-radius: 3px; font-family: monospace; }
.markdown-body h1, .markdown-body h2 { border-bottom: 1px solid #eaecef; padding-bottom: .3em; }

@keyframes slideIn { from { transform: translateX(100%); } to { transform: translateX(0); } }
</style>
