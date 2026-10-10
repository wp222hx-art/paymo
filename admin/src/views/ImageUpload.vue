<template>
  <div class="up">
    <el-image v-if="modelValue" :src="modelValue" class="img" fit="cover" />
    <el-upload :show-file-list="false" :http-request="upload" accept="image/png,image/jpeg,image/webp,image/gif">
      <el-button size="small" icon="Upload">{{ modelValue ? '更换' : '上传图片' }}</el-button>
    </el-upload>
    <el-button v-if="modelValue" size="small" link type="danger" @click="$emit('update:modelValue', '')">移除</el-button>
  </div>
</template>

<script setup>
import { post } from '../api';

defineProps({ modelValue: String });
const emit = defineEmits(['update:modelValue']);
const upload = async ({ file }) => {
  const fd = new FormData();
  fd.append('file', file);
  const r = await post('/upload', fd);
  emit('update:modelValue', r.url);
};
</script>

<style scoped>
.up { display: flex; align-items: center; gap: 10px; }
.img { width: 80px; height: 60px; border-radius: 6px; }
</style>
